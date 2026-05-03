/// AutoRefreshService — two responsibilities:
///   1. On app start, if ≥24 h since last successful sub refresh → background refresh.
///   2. After refresh (or on VPN start) → ping all proxies in the first Selector
///      group, pick lowest latency, fall back to next-best if connect fails in 7s.
///
/// RULES compliance:
///   - Does NOT modify _service() or FFI architecture.
///   - All Clash API calls via clashCore (main engine FFI only).
///   - Proxy selection via changeProxy — no new IPC.
library auto_refresh_service;

import 'dart:async';

import 'package:flclashx/clash/clash.dart';
import 'package:flclashx/common/print.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLastRefreshKey = 'auto_refresh_last_timestamp';
const _kRefreshInterval = Duration(hours: 24);
const _kDelayTestUrl = 'https://www.gstatic.com/generate_204';
const _kDelayTimeout = Duration(seconds: 10);
const _kConnectTimeout = Duration(seconds: 7);

class AutoRefreshService {
  AutoRefreshService._();
  static final AutoRefreshService instance = AutoRefreshService._();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Call once from AppController.init() after _initCore().
  /// Checks 24-hour window, refreshes subscription in background if needed.
  Future<void> checkAndRefresh(WidgetRef ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_kLastRefreshKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = lastMs == null
          ? _kRefreshInterval + const Duration(seconds: 1) // first run → refresh
          : Duration(milliseconds: now - lastMs);

      if (elapsed >= _kRefreshInterval) {
        commonPrint.log('AutoRefresh: 24h elapsed — refreshing subscription');
        await _refreshCurrentProfile(ref);
        await prefs.setInt(_kLastRefreshKey, DateTime.now().millisecondsSinceEpoch);
        commonPrint.log('AutoRefresh: refresh done, timestamp saved');
      } else {
        final remaining = _kRefreshInterval - elapsed;
        commonPrint.log(
            'AutoRefresh: next refresh in ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m');
      }
    } catch (e) {
      commonPrint.log('AutoRefresh.checkAndRefresh error: $e');
    }
  }

  /// Call on VPN start to auto-select the fastest available proxy.
  /// Runs entirely in background — does NOT block VPN startup.
  void autoSelectFastestAsync(WidgetRef ref) {
    unawaited(_autoSelectFastest(ref).catchError(
      (e) => commonPrint.log('AutoRefresh.autoSelectFastest error: $e'),
    ));
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _refreshCurrentProfile(WidgetRef ref) async {
    final currentId = ref.read(currentProfileIdProvider);
    if (currentId == null) {
      commonPrint.log('AutoRefresh: no current profile, skip refresh');
      return;
    }
    final profiles = ref.read(profilesProvider);
    final profile = profiles.getProfile(currentId);
    if (profile == null || profile.type == ProfileType.file) {
      commonPrint.log('AutoRefresh: profile is file type or null, skip refresh');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final sendHd = prefs.getBool('sendDeviceHeaders') ?? true;
      final updated = await profile
          .update(shouldSendHeaders: sendHd)
          .timeout(const Duration(seconds: 60),
              onTimeout: () => throw 'AutoRefresh: timeout after 60s');
      ref.read(profilesProvider.notifier).setProfile(updated);
      globalState.appController.applyProfileDebounce(silence: true);
      commonPrint.log('AutoRefresh: profile "${profile.label}" updated');
    } catch (e) {
      commonPrint.log('AutoRefresh: profile update failed: $e');
      rethrow;
    }
  }

  Future<void> _autoSelectFastest(WidgetRef ref) async {
    // Give Clash engine a moment to load the new config
    await Future.delayed(const Duration(seconds: 2));

    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) {
      commonPrint.log('AutoSelect: no groups available');
      return;
    }

    // Find the first Selector group (user-controlled proxy group)
    // Prefer a group named "Proxy" or "PROXY", else first Selector
    final selectorGroup = groups.firstWhere(
      (g) => g.type == GroupType.Selector &&
          (g.name == 'Proxy' || g.name == 'PROXY'),
      orElse: () => groups.firstWhere(
        (g) => g.type == GroupType.Selector,
        orElse: () => groups.first,
      ),
    );

    // Filter out special entries like DIRECT, REJECT, GLOBAL
    final candidates = selectorGroup.all
        .where((p) =>
            p.name != 'DIRECT' &&
            p.name != 'REJECT' &&
            p.name != 'GLOBAL' &&
            p.name != 'COMPATIBLE')
        .toList();

    if (candidates.isEmpty) {
      commonPrint.log('AutoSelect: no proxy candidates in group "${selectorGroup.name}"');
      return;
    }

    commonPrint.log(
        'AutoSelect: pinging ${candidates.length} proxies in "${selectorGroup.name}"');

    // Ping all proxies concurrently (batch of 20 max)
    final delays = <String, int>{}; // proxyName -> ms (-1 = timeout/error)
    final batches = <List<Proxy>>[];
    for (int i = 0; i < candidates.length; i += 20) {
      batches.add(candidates.sublist(
          i, i + 20 > candidates.length ? candidates.length : i + 20));
    }

    for (final batch in batches) {
      await Future.wait(batch.map((proxy) async {
        try {
          final delay = await clashCore
              .getDelay(_kDelayTestUrl, proxy.name)
              .timeout(_kDelayTimeout);
          final ms = delay.value ?? -1;
          delays[proxy.name] = ms > 0 ? ms : -1;
        } catch (_) {
          delays[proxy.name] = -1;
        }
      }));
    }

    // Sort by delay ascending; -1 (timeout) goes last
    final sorted = candidates.toList()
      ..sort((a, b) {
        final da = delays[a.name] ?? -1;
        final db = delays[b.name] ?? -1;
        if (da == -1 && db == -1) return 0;
        if (da == -1) return 1;
        if (db == -1) return -1;
        return da.compareTo(db);
      });

    commonPrint.log('AutoSelect: delay results — '
        '${sorted.take(5).map((p) => '${p.name}:${delays[p.name]}ms').join(', ')}');

    // Try candidates in order, fall back if connect test fails
    for (final candidate in sorted) {
      final ms = delays[candidate.name] ?? -1;
      if (ms == -1) {
        commonPrint.log('AutoSelect: skipping ${candidate.name} (no response)');
        continue;
      }

      commonPrint.log(
          'AutoSelect: trying ${candidate.name} (${ms}ms)…');

      // Select proxy
      await clashCore.changeProxy(ChangeProxyParams(
        groupName: selectorGroup.name,
        proxyName: candidate.name,
      ));
      await globalState.appController.updateGroups();

      // Verify connection: re-test delay with 7s budget
      bool connected = false;
      try {
        final verify = await clashCore
            .getDelay(_kDelayTestUrl, candidate.name)
            .timeout(_kConnectTimeout);
        connected = (verify.value ?? -1) > 0;
      } catch (_) {
        connected = false;
      }

      if (connected) {
        globalState.appController.changeProxyDebounce(
            selectorGroup.name, candidate.name);
        commonPrint.log(
            'AutoSelect: selected ${candidate.name} (${ms}ms) ✓');
        return;
      } else {
        commonPrint.log(
            'AutoSelect: ${candidate.name} failed connect test, trying next…');
      }
    }

    commonPrint.log('AutoSelect: all candidates failed, keeping current selection');
  }
}
