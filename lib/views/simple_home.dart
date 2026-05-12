import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flclashx/clash/clash.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/russia_preset.dart';
import 'package:flclashx/core/crash_logger.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/subscription_converter.dart';
// --- ДОБАВЛЕННЫЕ ИМПОРТЫ ---
import 'package:flclashx/views/settings.dart'; 
import 'package:flclashx/views/import_dialog.dart'; 
// ---------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flclashx/theme/app_theme.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _emerald   = AppColors.violet;
const _spring     = AppColors.lime;
const _orange     = AppColors.orange;

// ─── Theme helper ────────────────────────────────────────────────────────────
extension _ThemeX on BuildContext {
  bool get isDark   => Theme.of(this).brightness == Brightness.dark;
  Color get _bg      => isDark ? AppColors.darkBg        : AppColors.lightBg;
  Color get _surf    => isDark ? AppColors.darkSurface   : AppColors.lightSurface;
  Color get _t1      => isDark ? AppColors.darkT1        : AppColors.lightT1;
  Color get _t2      => isDark ? AppColors.darkT2        : AppColors.lightT2;
  Color get _t3      => isDark ? AppColors.darkT3        : AppColors.lightT3;
  Color get _border  => isDark ? AppColors.darkBorder    : AppColors.lightBorder;
}

// ─── Shared import helper ───────────────────────────────────────────────────
Future<void> doProfileImport({
  required String url,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  if (!globalState.appState.isInit) {
    bool ready = false;
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (globalState.appState.isInit) { ready = true; break; }
    }
    if (!ready) throw 'Ядро VPN ещё не готово.';
  }

  final prefs  = await SharedPreferences.getInstance();
  final sendHd = prefs.getBool('sendDeviceHeaders') ?? true;
  final base   = Profile.normal(url: url);

  Profile? profile;
  Object? firstError;
  try {
    profile = await base
        .update(shouldSendHeaders: sendHd)
        .timeout(const Duration(seconds: 60));
  } catch (e) { firstError = e; }

  if (profile == null) {
    Uint8List? rawBytes;
    try {
      final resp = await request.getFileResponseForUrl(url).timeout(const Duration(seconds: 30));
      rawBytes = resp.data;
    } catch (e) { throw firstError ?? e; }

    if (rawBytes == null || rawBytes.isEmpty) throw firstError ?? 'Пустой ответ.';
    final rawText = utf8.decode(rawBytes, allowMalformed: true).trim();
    final yaml = convertSubscriptionToClashYaml(rawText);
    profile = await base.saveFileWithString(yaml);
  }

  ref.read(profilesProvider.notifier).setProfile(profile!);
  if (ref.read(currentProfileIdProvider) == null) {
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }
  applyRussia2026Preset(ref);
}

// ─────────────────────────────────────────────────────────────────────────────
// Home screen
// ─────────────────────────────────────────────────────────────────────────────
class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});
  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView> {

  Future<void> _toggle(bool isOn) async {
    if (!isOn) {
      if (ref.read(currentProfileIdProvider) == null) {
        _snack('⚠️ Сначала импортируйте подписку.', error: true);
        return;
      }
    }
    try {
      await globalState.appController.updateStatus(!isOn);
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st);
      _snack('Ошибка: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black87)),
      backgroundColor: error ? AppColors.orange : AppColors.lime,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showImport(BuildContext ctx) {
    showDialog<void>(context: ctx,
        builder: (d) => ImportDialog(onImport: (url) async {
          Navigator.of(d).pop();
          await _runImport(ctx, url);
        }));
  }

  Future<void> _runImport(BuildContext ctx, String url) async {
    _snack('Загружаем подписку…');
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
      _snack('Подписка обновлена!');
    } catch (e) {
      _snack('Ошибка: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn    = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady = ref.watch(initProvider);
    
    return Scaffold(
      backgroundColor: context._bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            const SizedBox(height: 40),
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context._surf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context._border),
              ),
              child: Column(children: [
                Text('Raketa', style: AppFonts.logo(context._t1).copyWith(fontSize: 28)),
                const SizedBox(height: 8),
                Text(isOn ? 'Защита активна' : 'VPN отключен', style: AppFonts.body(context._t2)),
              ]),
            ),
            const SizedBox(height: 24),
            // Main Button
            GestureDetector(
              onTap: isReady ? () => _toggle(isOn) : null,
              child: Container(
                height: 64,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isReady ? (isOn ? AppColors.violetDark : AppColors.violet) : context._t3,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(isOn ? 'ОТКЛЮЧИТЬ' : 'ПОДКЛЮЧИТЬ', style: AppFonts.btnPrimary(Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Actions
            Row(children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.add_link,
                  label: 'Импорт',
                  onTap: () => _showImport(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.settings,
                  label: 'Настройки',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsView()),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context._surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context._border),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.violet),
          const SizedBox(height: 8),
          Text(label, style: AppFonts.bodyMedium(context._t1)),
        ]),
      ),
    );
  }
}
