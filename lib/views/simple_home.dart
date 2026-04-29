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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Palette — light/dark adaptive ───────────────────────────────────────────
// Accent set: violet (trust+care), sky-blue (openness), lime (energy),
// orange (optimism), slate (reliability)
const _violet    = Color(0xFF7B5EA7);
const _violetLt  = Color(0xFF9D7EC9);
const _sky       = Color(0xFF4BBFFF);
const _skyLt     = Color(0xFF78D4FF);
const _lime      = Color(0xFF8BC34A);
const _limeDk    = Color(0xFF6DA033);
const _orange    = Color(0xFFFF7043);
const _slate     = Color(0xFF78909C);

// Dark theme surfaces
const _bgDark    = Color(0xFF0F0F14);
const _surfDark  = Color(0xFF1C1C26);
const _surfHiDk  = Color(0xFF272733);
const _divDark   = Color(0xFF2E2E3E);

// Light theme surfaces  
const _bgLight   = Color(0xFFF4F4F8);
const _surfLight = Color(0xFFFFFFFF);
const _surfHiLt  = Color(0xFFEEEEF5);
const _divLight  = Color(0xFFDDDDE8);

// Text — always referenced via theme, not hardcoded

// ─────────────────────────────────────────────────────────────────────────────
// Theme helper
// ─────────────────────────────────────────────────────────────────────────────
extension _ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg       => isDark ? _bgDark    : _bgLight;
  Color get surf     => isDark ? _surfDark  : _surfLight;
  Color get surfHi   => isDark ? _surfHiDk  : _surfHiLt;
  Color get divider  => isDark ? _divDark   : _divLight;
  Color get textPri  => isDark ? const Color(0xFFEEEEF5) : const Color(0xFF1A1A2E);
  Color get textSec  => isDark ? const Color(0xFF9999BB) : const Color(0xFF666688);
  Color get textTer  => isDark ? const Color(0xFF4A4A6A) : const Color(0xFFAAAAAA);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared import helper — supports YAML, base64, single URIs
// ─────────────────────────────────────────────────────────────────────────────
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
    if (!ready) {
      throw 'Ядро VPN ещё не готово. Подождите несколько секунд и попробуйте снова.';
    }
  }

  final prefs  = await SharedPreferences.getInstance();
  final sendHd = prefs.getBool('sendDeviceHeaders') ?? true;
  final base   = Profile.normal(url: url);

  // Attempt 1: standard Profile.update() — works for Clash YAML subs
  Profile? profile;
  Object? firstError;
  try {
    profile = await base
        .update(shouldSendHeaders: sendHd)
        .timeout(const Duration(seconds: 60),
            onTimeout: () => throw 'Превышено время ожидания (60 с).');
  } catch (e) { firstError = e; }

  // Attempt 2: download raw + fix YAML or convert format
  if (profile == null) {
    Uint8List? rawBytes;
    try {
      final resp = await request
          .getFileResponseForUrl(url)
          .timeout(const Duration(seconds: 30));
      rawBytes = resp.data;
    } catch (e) { throw firstError ?? e; }

    if (rawBytes == null || rawBytes.isEmpty) throw firstError ?? 'Пустой ответ сервера.';
    final rawText = utf8.decode(rawBytes, allowMalformed: true).trim();
    final origErr = firstError?.toString() ?? '';
    final isYamlErr = origErr.contains('yaml') || origErr.contains('mapping') ||
        origErr.contains('line ');

    // 2a: valid Clash YAML with unquoted colon values (paid VPN server names)
    if (isYamlErr && _looksLikeClashYaml(rawText)) {
      try { profile = await base.saveFileWithString(_fixYamlColonValues(rawText)); }
      catch (_) {}
    }

    // 2b: format conversion (base64 proxy list, single URI, etc.)
    if (profile == null) {
      final String yaml;
      try { yaml = convertSubscriptionToClashYaml(rawText); }
      catch (e) {
        if (isYamlErr) throw 'Ошибка YAML: $firstError\nОшибка конвертации: $e';
        throw firstError ?? e;
      }
      try { profile = await base.saveFileWithString(yaml); }
      catch (e) { throw 'Конфиг невалидный: $e\nИсходная ошибка: $firstError'; }
    }
  }

  ref.read(profilesProvider.notifier).setProfile(profile);
  if (ref.read(currentProfileIdProvider) == null) {
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
    globalState.appController.applyProfileDebounce(silence: true);
  }
}

// ─── YAML helpers ─────────────────────────────────────────────────────────────
bool _looksLikeClashYaml(String s) =>
    s.contains('proxies:') || s.contains('proxy-groups:') ||
    s.contains('mixed-port:') || (s.contains('port:') && s.contains('mode:'));

String _fixYamlColonValues(String yaml) =>
    yaml.split('\n').map(_fixYamlLine).join('\n');

String _fixYamlLine(String line) {
  final stripped = line.trimLeft();
  if (stripped.isEmpty || stripped.startsWith('#') || stripped.startsWith('---')) return line;
  final m = RegExp(r'^(\s*(?:-\s+)?)(\w[\w\-_.]*)(\s*:\s+)(.+)$').firstMatch(line);
  if (m == null) return line;
  final prefix = m.group(1)!;
  final key    = m.group(2)!;
  final sep    = m.group(3)!;
  final value  = m.group(4)!.trimRight();
  if (!_needsYamlQuoting(value)) return line;
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '$prefix$key$sep"$escaped"';
}

bool _needsYamlQuoting(String v) {
  if (v.length >= 2 &&
      ((v.startsWith('"') && v.endsWith('"')) ||
       (v.startsWith("'") && v.endsWith("'")))) return false;
  if (RegExp(r'^\d+$').hasMatch(v)) return false;
  if (const {'true','false','null','~','|','>','|-','>-'}.contains(v)) return false;
  return v.contains(': ') || v.endsWith(':');
}

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
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 10.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> _toggle(bool isOn) async {
    try {
      await globalState.appController.updateStatus(!isOn);
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st);
      if (mounted) _snack('Ошибка: $e', error: true);
    }
  }



  void _snack(String msg, {bool error = false,
      Duration dur = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _orange : _lime,
      duration: dur,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isOn     = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady  = ref.watch(initProvider);

    final activeColor  = isOn ? _lime    : _slate;
    final btnGrad      = isOn ? [_limeDk, _lime] : [_violet, _violetLt];
    final glowColor    = isOn
        ? _lime.withOpacity(0.30)
        : _violet.withOpacity(0.20);
    final bgCol        = context.bg;
    final textPri      = context.textPri;
    final textSec      = context.textSec;
    final textTer      = context.textTer;

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const SizedBox(height: 48),

            // ── Logo / icon ────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                key: ValueKey(isOn),
                isOn ? Icons.shield_rounded : Icons.shield_outlined,
                size: 68,
                color: isOn ? _lime : _slate,
              ),
            ),
            const SizedBox(height: 14),
            Text('FlClashR',
                style: TextStyle(
                    fontSize: 42, fontWeight: FontWeight.w900,
                    color: textPri, letterSpacing: -1)),
            const SizedBox(height: 6),
            // Init indicator
            AnimatedOpacity(
              opacity: isReady ? 0 : 1,
              duration: const Duration(milliseconds: 600),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: _sky.withOpacity(0.8))),
                const SizedBox(width: 8),
                Text('Инициализация…',
                    style: TextStyle(fontSize: 12, color: _sky.withOpacity(0.8))),
              ]),
            ),

            const Spacer(),

            // ── Big toggle button ──────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Container(
                width: double.infinity, height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: isReady ? btnGrad : [_slate, _slate.withOpacity(0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: isReady && isOn ? [BoxShadow(
                    color: glowColor,
                    blurRadius: 18 + _pulseAnim.value,
                    spreadRadius: _pulseAnim.value * 0.4,
                  )] : [],
                ),
                child: child,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: isReady ? () => _toggle(isOn) : null,
                  child: Center(child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isReady
                        ? Text(
                            key: ValueKey(isOn),
                            isOn ? 'Отключить' : 'Включить',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold,
                                color: Colors.white),
                          )
                        : Text('Подождите…',
                            style: TextStyle(fontSize: 18,
                                color: Colors.white.withOpacity(0.6))),
                  )),
                ),
              ),
            ),
            const SizedBox(height: 10),

            const Spacer(),

            // ── Action buttons ─────────────────────────────────────────────
            _RowBtn(icon: Icons.tune_rounded, label: 'Режимы',
                onTap: () => _showModes(context)),
            const SizedBox(height: 10),
            _RowBtn(icon: Icons.settings_rounded, label: 'Настройки',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsView()))),

            const SizedBox(height: 28),
            Text('from pavel with love ♥',
                style: TextStyle(fontSize: 11, color: textTer)),
            const SizedBox(height: 14),
          ]),
        ),
      ),
    );
  }

  void _showModes(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: ctx.surf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Режимы', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800, color: c.textPri)),
          const SizedBox(height: 4),
          Text('Готовый набор правил маршрутизации',
              style: TextStyle(fontSize: 13, color: c.textSec)),
          const SizedBox(height: 20),
          _SheetTile(icon: Icons.flag_rounded, color: _violet,
              title: 'Россия 2026',
              subtitle: 'YouTube, Telegram — VPN. Банки — напрямую.',
              onTap: () {
                applyRussia2026Preset(ref);
                Navigator.of(c).pop();
                _snack('Пресет «Россия 2026» применён');
              }),
          const SizedBox(height: 10),
          _SheetTile(icon: Icons.add_link_rounded, color: _sky,
              title: 'Импорт подписки',
              subtitle: 'Вставить ссылку на прокси-ключ',
              onTap: () { Navigator.of(c).pop(); _showImport(ctx); }),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }

  void _showImport(BuildContext ctx) {
    showDialog<void>(context: ctx,
        builder: (d) => ImportDialog(onImport: (url) async {
          Navigator.of(d).pop();
          await _runImport(ctx, url);
        }));
  }

  Future<void> _runImport(BuildContext ctx, String url) async {
    final ctrl = ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: _LoadingRow('Загружаем подписку…'),
      duration: Duration(seconds: 90),
    ));
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
      ctrl.close();
      _snack('✓ Подписка добавлена');
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st, context: 'home import');
      ctrl.close();
      _snack('Ошибка: $e', error: true, dur: const Duration(seconds: 8));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings screen
// ─────────────────────────────────────────────────────────────────────────────
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});
  @override
  ConsumerState<SettingsView> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsView> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = '${i.version}+${i.buildNumber}');
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _orange : _lime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final profiles  = ref.watch(profilesProvider);
    final currentId = ref.watch(currentProfileIdProvider);
    final current   = profiles.getProfile(currentId);
    final isReady   = ref.watch(initProvider);
    final textPri   = context.textPri;
    final bgCol     = context.bg;

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: bgCol, foregroundColor: textPri, elevation: 0,
        title: Text('Настройки',
            style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 20, color: textPri)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [

        // ── Init banner ────────────────────────────────────────────────────
        if (!isReady)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _sky.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _sky.withOpacity(0.35)),
            ),
            child: Row(children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _sky)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Ядро VPN инициализируется. Кнопка «Включить» станет активна автоматически.',
                style: TextStyle(color: _sky, fontSize: 13),
              )),
            ]),
          ),

        // ── Subscription ───────────────────────────────────────────────────
        _SectionHdr('Подписка', context),
        _Card(context: context, child: Column(children: [
          if (current != null) ...[
            _InfoRow(label: 'Активная', value: current.label ?? current.id, context: context),
            _Div(context),
          ],
          _Tile(icon: Icons.add_link_rounded, label: 'Добавить подписку',
              sublabel: isReady ? null : 'Ожидание инициализации…',
              onTap: isReady ? () => _showImport(context) : null,
              context: context),
          if (current != null) ...[
            _Div(context),
            _Tile(icon: Icons.refresh_rounded, label: 'Обновить подписку',
                onTap: isReady ? () => _updateCurrent(context, current) : null,
                context: context),
          ],
          if (profiles.isNotEmpty) ...[
            _Div(context),
            _Tile(icon: Icons.list_rounded,
                label: 'Все подписки (${profiles.length})',
                trailing: Icon(Icons.chevron_right_rounded,
                    color: context.textTer, size: 20),
                onTap: () => _showProfileList(context, profiles, currentId),
                context: context),
          ],
        ])),
        const SizedBox(height: 20),

        // ── VPN ────────────────────────────────────────────────────────────
        _SectionHdr('VPN', context),
        _Card(context: context, child: _Tile(
          icon: Icons.flag_rounded, label: 'Пресет «Россия 2026»',
          context: context,
          onTap: () {
            applyRussia2026Preset(ref);
            _snack('Пресет применён');
          },
        )),
        const SizedBox(height: 20),

        // ── Diagnostics ─────────────────────────────────────────────────────
        _SectionHdr('Диагностика', context),
        _Card(context: context, child: Column(children: [
          _Tile(icon: Icons.bug_report_outlined, label: 'Просмотр лога',
              trailing: Icon(Icons.chevron_right_rounded,
                  color: context.textTer, size: 20),
              context: context,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LogView()))),
          _Div(context),
          _Tile(icon: Icons.delete_outline_rounded, label: 'Очистить лог',
              labelColor: _orange, context: context, onTap: () async {
                await CrashLogger.instance.clearLogs();
                _snack('Лог очищен');
              }),
        ])),
        const SizedBox(height: 20),

        // ── About ────────────────────────────────────────────────────────────
        _SectionHdr('О приложении', context),
        _Card(context: context, child: Column(children: [
          _InfoRow(label: 'Приложение', value: 'FlClashR', context: context),
          _Div(context),
          _InfoRow(label: 'Версия', value: _version, context: context),
        ])),
      ]),
    );
  }

  void _showImport(BuildContext ctx) {
    showDialog<void>(context: ctx,
        builder: (d) => ImportDialog(onImport: (url) async {
          Navigator.of(d).pop();
          await _runImport(ctx, url);
        }));
  }

  Future<void> _runImport(BuildContext ctx, String url) async {
    final ctrl = ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: _LoadingRow('Загружаем подписку…'),
      duration: Duration(seconds: 90),
    ));
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
      ctrl.close();
      _snack('✓ Подписка добавлена');
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st, context: 'settings import');
      ctrl.close();
      _snack('Ошибка: $e', error: true);
    }
  }

  Future<void> _updateCurrent(BuildContext ctx, Profile p) async {
    final ctrl = ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: _LoadingRow('Обновляем подписку…'),
      duration: Duration(seconds: 90),
    ));
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = await p
          .update(shouldSendHeaders: prefs.getBool('sendDeviceHeaders') ?? true)
          .timeout(const Duration(seconds: 60),
              onTimeout: () => throw 'Превышено время ожидания');
      ref.read(profilesProvider.notifier).setProfile(updated);
      globalState.appController.applyProfileDebounce(silence: true);
      ctrl.close();
      _snack('✓ Подписка обновлена');
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st, context: 'update profile');
      ctrl.close();
      _snack('Ошибка: $e', error: true);
    }
  }

  void _showProfileList(BuildContext ctx, List<Profile> list, String? cid) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: ctx.surf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Подписки', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: c.textPri)),
          const SizedBox(height: 16),
          ...list.map((p) {
            final active = p.id == cid;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(active
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
                  color: active ? _violet : c.textTer),
              title: Text(p.label ?? p.id, style: TextStyle(
                  color: active ? _violet : c.textPri,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
              subtitle: p.url.isNotEmpty
                  ? Text(p.url, style: TextStyle(color: c.textTer, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: c.textTer, size: 20),
                onPressed: () {
                  Navigator.of(c).pop();
                  globalState.appController.deleteProfile(p.id);
                },
              ),
              onTap: () {
                ref.read(currentProfileIdProvider.notifier).value = p.id;
                globalState.appController.applyProfileDebounce(silence: true);
                Navigator.of(c).pop();
              },
            );
          }),
        ]),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log viewer
// ─────────────────────────────────────────────────────────────────────────────
class LogView extends StatefulWidget {
  const LogView({super.key});
  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  String _log    = 'Загрузка…';
  bool   _copied = false;
  final  _scroll = ScrollController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    final text = await CrashLogger.instance.readLogs();
    if (!mounted) return;
    setState(() => _log = text.isEmpty ? 'Лог пуст.' : text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _log));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.bg,
    appBar: AppBar(
      backgroundColor: context.bg, foregroundColor: context.textPri, elevation: 0,
      title: Text('Лог ошибок',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
              color: context.textPri)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить', onPressed: _load),
        IconButton(
            icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                color: _copied ? _lime : context.textPri),
            tooltip: 'Скопировать',
            onPressed: _copy),
        IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: _orange),
            tooltip: 'Очистить',
            onPressed: () async {
              final ok = await showDialog<bool>(context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: context.surf,
                    title: Text('Очистить лог?',
                        style: TextStyle(color: context.textPri)),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(d).pop(false),
                          child: Text('Отмена',
                              style: TextStyle(color: context.textSec))),
                      TextButton(onPressed: () => Navigator.of(d).pop(true),
                          child: Text('Очистить',
                              style: TextStyle(color: _orange))),
                    ],
                  ));
              if (ok == true) { await CrashLogger.instance.clearLogs(); await _load(); }
            }),
        const SizedBox(width: 4),
      ],
    ),
    body: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: context.surfHi,
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: _sky),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Нажмите кнопку копирования ↗ и отправьте лог в чат с Claude',
            style: TextStyle(fontSize: 12, color: context.textSec),
          )),
          if (_copied)
            Text('Скопировано!',
                style: TextStyle(fontSize: 12, color: _lime,
                    fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(14),
          child: SelectableText(_log,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                  color: context.textSec, height: 1.5)),
        ),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Import dialog
// ─────────────────────────────────────────────────────────────────────────────
class ImportDialog extends StatefulWidget {
  final Future<void> Function(String url) onImport;
  const ImportDialog({super.key, required this.onImport});
  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _ctrl = TextEditingController();
  bool _busy  = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    try { await widget.onImport(url); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.surf,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text('Импорт подписки',
        style: TextStyle(color: context.textPri, fontWeight: FontWeight.bold)),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Вставьте ссылку (vmess://, vless://, ss://, https://…)',
          style: TextStyle(color: context.textSec, fontSize: 13)),
      const SizedBox(height: 14),
      TextField(
        controller: _ctrl, autofocus: true, enabled: !_busy,
        style: TextStyle(color: context.textPri, fontSize: 14),
        maxLines: 3, minLines: 1,
        decoration: InputDecoration(
          hintText: 'https://example.com/sub?token=…',
          hintStyle: TextStyle(color: context.textTer, fontSize: 13),
          filled: true, fillColor: context.surfHi,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
        onSubmitted: (_) => _submit(),
      ),
    ]),
    actions: [
      TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('Отмена', style: TextStyle(color: context.textSec))),
      FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _violet),
          child: _busy
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Добавить',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Design atoms — all adaptive
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHdr extends StatelessWidget {
  final String text;
  final BuildContext ctx;
  const _SectionHdr(this.text, this.ctx);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(text.toUpperCase(), style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: ctx.textTer, letterSpacing: 1.4)),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final BuildContext context;
  const _Card({required this.child, required this.context});
  @override
  Widget build(BuildContext ctx) => Container(
    decoration: BoxDecoration(
        color: context.surf,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 2)),
        ]),
    child: child,
  );
}

class _Div extends StatelessWidget {
  final BuildContext ctx;
  const _Div(this.ctx);
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: ctx.divider, indent: 52);
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final BuildContext context;
  const _Tile({required this.icon, required this.label, required this.context,
      this.sublabel, this.labelColor, this.trailing, this.onTap});
  @override
  Widget build(BuildContext ctx) => ListTile(
    leading: Icon(icon, color: onTap != null ? _violet : context.textTer, size: 22),
    title: Text(label, style: TextStyle(
        color: onTap != null ? (labelColor ?? context.textPri) : context.textTer,
        fontSize: 15)),
    subtitle: sublabel != null
        ? Text(sublabel!, style: TextStyle(color: context.textTer, fontSize: 12))
        : null,
    trailing: trailing,
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final BuildContext context;
  const _InfoRow({required this.label, required this.value, required this.context});
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Text(label, style: TextStyle(color: context.textSec, fontSize: 15)),
      const Spacer(),
      Text(value, style: TextStyle(color: context.textPri, fontSize: 15)),
    ]),
  );
}

class _RowBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RowBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 60,
    child: Material(
      color: context.surf, borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18), onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(children: [
            Icon(icon, size: 22, color: _violet),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 17, color: context.textPri,
                fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: context.textTer, size: 20),
          ]),
        ),
      ),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.color,
      required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: context.surfHi, borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold,
                    color: context.textPri)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSec)),
              ])),
          Icon(Icons.chevron_right_rounded, color: context.textTer, size: 18),
        ]),
      ),
    ),
  );
}

class _LoadingRow extends StatelessWidget {
  final String text;
  const _LoadingRow(this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
    const SizedBox(width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
    const SizedBox(width: 12),
    Text(text),
  ]);
}
