import 'dart:async';

import 'package:flclashx/clash/clash.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/russia_preset.dart';
import 'package:flclashx/core/crash_logger.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Colours ─────────────────────────────────────────────────────────────────
const _bg          = Color(0xFF0A0A0A);
const _surface     = Color(0xFF1A1A1A);
const _surfaceHigh = Color(0xFF252525);
const _green       = Color(0xFF00FF9F);
const _greenDk     = Color(0xFF00CC7F);
const _red         = Color(0xFFFF3B5C);
const _redLt       = Color(0xFFFF6B81);
const _textPri     = Color(0xFFFFFFFF);
const _textSec     = Color(0xFFAAAAAA);
const _textTer     = Color(0xFF555555);
const _divider     = Color(0xFF2A2A2A);

// ─────────────────────────────────────────────────────────────────────────────
// Home screen
// ─────────────────────────────────────────────────────────────────────────────
class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});
  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ── VPN toggle ─────────────────────────────────────────────────────────────
  Future<void> _toggle(bool isStarted) async {
    try {
      await globalState.appController.updateStatus(!isStarted);
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: _red),
        );
      }
    }
  }

  // ── Format uptime ──────────────────────────────────────────────────────────
  String _fmt(int? s) {
    if (s == null) return 'Отключено';
    if (s < 60)   return 'Подключено · ${s}с';
    if (s < 3600) return 'Подключено · ${s ~/ 60}м ${s % 60}с';
    return 'Подключено · ${s ~/ 3600}ч ${(s % 3600) ~/ 60}м';
  }

  @override
  Widget build(BuildContext context) {
    final isOn     = ref.watch(runTimeProvider.select((t) => t != null));
    final runTime  = ref.watch(runTimeProvider);
    final colors   = isOn ? [_greenDk, _green] : [_red, _redLt];
    final glow     = (isOn ? _green : _red).withOpacity(0.28);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 52),
              // ── Logo ───────────────────────────────────────────────────────
              Icon(
                isOn ? Icons.shield : Icons.shield_outlined,
                size: 72,
                color: isOn ? _green : _textTer,
              ),
              const SizedBox(height: 16),
              const Text(
                'FlClashR',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: _textPri,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              // ── Big toggle button ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Container(
                  width: double.infinity,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(colors: colors),
                    boxShadow: [
                      BoxShadow(
                        color: glow,
                        blurRadius: isOn ? 16 + _pulseAnim.value : 10,
                        spreadRadius: isOn ? _pulseAnim.value * 0.5 : 0,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => _toggle(isOn),
                    child: Center(
                      child: Text(
                        isOn ? 'Отключить' : 'Включить',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textPri,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _fmt(runTime),
                style: TextStyle(
                  color: isOn ? _green : _textTer,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              // ── Bottom buttons ─────────────────────────────────────────────
              _RowButton(
                icon: Icons.tune_rounded,
                label: 'Режимы',
                onTap: () => _showModes(context),
              ),
              const SizedBox(height: 10),
              _RowButton(
                icon: Icons.settings_rounded,
                label: 'Настройки',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsView()),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'from pavel with love ♥',
                style: TextStyle(fontSize: 11, color: _textTer),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modes bottom sheet ─────────────────────────────────────────────────────
  void _showModes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Режимы',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textPri)),
              const SizedBox(height: 4),
              const Text('Готовый набор правил маршрутизации',
                  style: TextStyle(fontSize: 13, color: _textSec)),
              const SizedBox(height: 20),
              _SheetTile(
                icon: Icons.flag_rounded,
                color: _red,
                title: 'Россия 2026',
                subtitle: 'YouTube, Telegram — через VPN. Банки — напрямую.',
                onTap: () {
                  applyRussia2026Preset(ref);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пресет «Россия 2026» применён')),
                  );
                },
              ),
              const SizedBox(height: 10),
              _SheetTile(
                icon: Icons.add_link_rounded,
                color: _green,
                title: 'Импорт подписки',
                subtitle: 'Вставить ссылку на прокси-ключ',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showImport(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Import dialog ──────────────────────────────────────────────────────────
  void _showImport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dCtx) => _ImportDialog(
        onImport: (url) async {
          Navigator.of(dCtx).pop();
          await _doImport(context, url);
        },
      ),
    );
  }

  Future<void> _doImport(BuildContext context, String url) async {
    // Show loading indicator
    final loading = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Загружаем подписку…'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final prefs      = await SharedPreferences.getInstance();
      final sendHeaders = prefs.getBool('sendDeviceHeaders') ?? true;
      final profile    = await Profile.normal(url: url).update(
        shouldSendHeaders: sendHeaders,
      );

      // Register in Riverpod state (same as addProfile in controller)
      ref.read(profilesProvider.notifier).setProfile(profile);
      if (ref.read(currentProfileIdProvider) == null) {
        ref.read(currentProfileIdProvider.notifier).value = profile.id;
        globalState.appController.applyProfileDebounce(silence: true);
      }

      loading.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Подписка добавлена'),
            backgroundColor: _greenDk,
          ),
        );
      }
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st, context: 'import profile');
      loading.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: _red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings screen
// ─────────────────────────────────────────────────────────────────────────────
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});
  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version} (${i.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles   = ref.watch(profilesProvider);
    final currentId  = ref.watch(currentProfileIdProvider);
    final current    = profiles.getProfile(currentId);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPri,
        elevation: 0,
        title: const Text(
          'Настройки',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Subscription section ─────────────────────────────────────────
          _SectionHeader('Подписка'),
          _Card(
            child: Column(
              children: [
                if (current != null) ...[
                  _InfoRow(
                    label: 'Активная',
                    value: current.label ?? current.id,
                  ),
                  const _Divider(),
                ],
                _Tile(
                  icon: Icons.add_link_rounded,
                  label: 'Добавить подписку',
                  onTap: () => _showImport(context),
                ),
                if (current != null) ...[
                  const _Divider(),
                  _Tile(
                    icon: Icons.refresh_rounded,
                    label: 'Обновить подписку',
                    onTap: () => _updateCurrent(context, current),
                  ),
                ],
                if (profiles.isNotEmpty) ...[
                  const _Divider(),
                  _Tile(
                    icon: Icons.list_rounded,
                    label: 'Список подписок (${profiles.length})',
                    trailing: const Icon(Icons.chevron_right_rounded, color: _textTer, size: 20),
                    onTap: () => _showProfileList(context, profiles, currentId),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── VPN section ──────────────────────────────────────────────────
          _SectionHeader('VPN'),
          _Card(
            child: Column(
              children: [
                _Tile(
                  icon: Icons.flag_rounded,
                  label: 'Применить пресет «Россия 2026»',
                  onTap: () {
                    applyRussia2026Preset(ref);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Пресет применён')),
                    );
                  },
                ),
                const _Divider(),
                _Tile(
                  icon: Icons.dns_rounded,
                  label: 'Расширенные настройки',
                  trailing: const Icon(Icons.chevron_right_rounded, color: _textTer, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _AdvancedView()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── About section ────────────────────────────────────────────────
          _SectionHeader('О приложении'),
          _Card(
            child: Column(
              children: [
                _InfoRow(label: 'Версия', value: _version),
                const _Divider(),
                _InfoRow(label: 'Приложение', value: 'FlClashR'),
                const _Divider(),
                _Tile(
                  icon: Icons.bug_report_rounded,
                  label: 'Скопировать путь к логу',
                  onTap: () async {
                    final path = await CrashLogger.instance.getLogPath();
                    await Clipboard.setData(ClipboardData(text: path));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Скопировано: $path')),
                      );
                    }
                  },
                ),
                const _Divider(),
                _Tile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Очистить лог',
                  labelColor: _red,
                  onTap: () async {
                    await CrashLogger.instance.clearLogs();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Лог очищен')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Import ────────────────────────────────────────────────────────────────
  void _showImport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dCtx) => _ImportDialog(
        onImport: (url) async {
          Navigator.of(dCtx).pop();
          await _doImport(context, url);
        },
      ),
    );
  }

  Future<void> _doImport(BuildContext context, String url) async {
    final snack = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Загружаем…'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await Profile.normal(url: url)
          .update(shouldSendHeaders: prefs.getBool('sendDeviceHeaders') ?? true);

      ref.read(profilesProvider.notifier).setProfile(profile);
      if (ref.read(currentProfileIdProvider) == null) {
        ref.read(currentProfileIdProvider.notifier).value = profile.id;
        globalState.appController.applyProfileDebounce(silence: true);
      }
      snack.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Подписка добавлена'), backgroundColor: _greenDk),
        );
      }
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st, context: 'settings import');
      snack.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: _red,
              duration: const Duration(seconds: 6)),
        );
      }
    }
  }

  // ── Update current profile ─────────────────────────────────────────────────
  Future<void> _updateCurrent(BuildContext context, Profile profile) async {
    final snack = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12), Text('Обновляем подписку…'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final updated = await profile.update();
      ref.read(profilesProvider.notifier).setProfile(updated);
      globalState.appController.applyProfileDebounce(silence: true);
      snack.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Подписка обновлена'), backgroundColor: _greenDk),
        );
      }
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st, context: 'update profile');
      snack.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: _red,
              duration: const Duration(seconds: 6)),
        );
      }
    }
  }

  // ── Profile list sheet ────────────────────────────────────────────────────
  void _showProfileList(
    BuildContext context,
    List<Profile> profiles,
    String? currentId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Подписки',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPri)),
              const SizedBox(height: 16),
              ...profiles.map((p) {
                final isActive = p.id == currentId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isActive ? _green : _textTer,
                  ),
                  title: Text(
                    p.label ?? p.id,
                    style: TextStyle(
                      color: isActive ? _green : _textPri,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: p.url.isNotEmpty
                      ? Text(p.url, style: const TextStyle(color: _textTer, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: _textTer, size: 20),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      globalState.appController.deleteProfile(p.id);
                    },
                  ),
                  onTap: () {
                    ref.read(currentProfileIdProvider.notifier).value = p.id;
                    globalState.appController.applyProfileDebounce(silence: true);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advanced settings (thin wrapper to existing views to keep logic intact)
// ─────────────────────────────────────────────────────────────────────────────
class _AdvancedView extends ConsumerWidget {
  const _AdvancedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPri,
        elevation: 0,
        title: const Text('Дополнительно',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _SectionHeader('Сеть'),
          _Card(
            child: Column(
              children: [
                _Tile(
                  icon: Icons.vpn_lock_rounded,
                  label: 'VPN и TUN',
                  trailing: const Icon(Icons.chevron_right_rounded, color: _textTer, size: 20),
                  onTap: () {
                    // Opens the existing access control / vpn settings page
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const _AccessControlWrapper(),
                    ));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Thin wrapper that reuses the existing AccessView
class _AccessControlWrapper extends StatelessWidget {
  const _AccessControlWrapper();
  @override
  Widget build(BuildContext context) {
    // Import access view lazily to avoid pulling in all desktop dependencies
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPri,
        elevation: 0,
        title: const Text('Контроль доступа',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Text(
          'Раздел в разработке',
          style: TextStyle(color: _textSec),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import dialog (shared between Home and Settings)
// ─────────────────────────────────────────────────────────────────────────────
class _ImportDialog extends StatefulWidget {
  final Future<void> Function(String url) onImport;
  const _ImportDialog({required this.onImport});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _ctrl = TextEditingController();
  bool _busy  = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    await widget.onImport(url);
    // Dialog already popped by onImport, no need to pop here
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Импорт подписки',
            style: TextStyle(color: _textPri, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Вставьте ссылку на подписку\n(vmess://, vless://, ss://, https://…)',
              style: TextStyle(color: _textSec, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              enabled: !_busy,
              style: const TextStyle(color: _textPri, fontSize: 14),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'https://example.com/sub?token=…',
                hintStyle: const TextStyle(color: _textTer, fontSize: 13),
                filled: true,
                fillColor: _surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Отмена', style: TextStyle(color: _textSec)),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: _green),
            child: _busy
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Добавить',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Design atoms
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _textTer, letterSpacing: 1.2,
            )),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: _divider, indent: 52);
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({
    required this.icon,
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: _textSec, size: 22),
        title: Text(label,
            style: TextStyle(
              color: labelColor ?? _textPri,
              fontSize: 15,
            )),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: _textSec, fontSize: 15)),
            const Spacer(),
            Text(value,
                style: const TextStyle(color: _textPri, fontSize: 15),
                textAlign: TextAlign.right),
          ],
        ),
      );
}

class _RowButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RowButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 60,
        child: Material(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: _textSec),
                  const SizedBox(width: 14),
                  Text(label,
                      style: const TextStyle(fontSize: 17, color: _textPri)),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: _textTer, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetTile({
    required this.icon, required this.color,
    required this.title, required this.subtitle, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: _textPri)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: _textSec)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _textTer, size: 18),
              ],
            ),
          ),
        ),
      );
}
