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
import 'package:flclashx/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Palette — brand colors from AppTheme (mapped to local constants) ─────────
// Primary: Emerald #00703C / #00A055 (dark)
// Accent:  Spring  #A0E720 / #7AB800 (light)
// Info:    Sky     #00ADEE
// Success: Arctic  #42E3B4
// Warning/Error: orange #FF8A00

const _emerald   = AppColors.violet;
const _emeraldLt = AppColors.violetLight;
const _spring    = AppColors.lime;
const _springDk  = AppColors.limeDark;
const _sky       = AppColors.violet;
const _arctic    = AppColors.lime;
const _orange    = AppColors.orange;

// Kept for backward compat with palette code below — mapped to brand
const _violet    = _emerald;        // primary interactive
const _violetLt  = _emeraldLt;     // primary on dark
const _lime      = _spring;        // success/active
const _limeDk    = _springDk;      // success on light
const _slate     = AppColors.lightT2;

// Dark theme surfaces — use AppColors
// (kept as aliases for legacy code — resolved via _ThemeX extension)
const _bgDark    = AppColors.darkBg;
const _surfDark  = AppColors.darkSurface;
const _surfHiDk  = AppColors.darkSurfaceHi;
const _divDark   = AppColors.darkDivider;

// Light theme surfaces
const _bgLight   = AppColors.lightBg;
const _surfLight = AppColors.lightSurface;
const _surfHiLt  = AppColors.lightSurfaceHi;
const _divLight  = AppColors.lightDivider;

// Text — always referenced via theme, not hardcoded

// ─────────────────────────────────────────────────────────────────────────────
// Theme helper — delegates to AppColors for consistency
// ─────────────────────────────────────────────────────────────────────────────
// BuildContextThemeX is defined in app_theme.dart — provides ctx.bg, ctx.surf,
// ctx.textPri, ctx.textSec, ctx.textTer, ctx.isDark, ctx.border, etc.
// _ThemeX alias kept for backward compatibility in this file.
extension _ThemeX on BuildContext {
  bool get isDark   => Theme.of(this).brightness == Brightness.dark;
  // All color getters delegated to AppColors via BuildContextThemeX (app_theme.dart)
  Color get _bg      => isDark ? AppColors.darkBg       : AppColors.lightBg;
  Color get _surf    => isDark ? AppColors.darkSurface  : AppColors.lightSurface;
  Color get _t1      => isDark ? AppColors.darkT1       : AppColors.lightT1;
  Color get _t2      => isDark ? AppColors.darkT2       : AppColors.lightT2;
  Color get _t3      => isDark ? AppColors.darkT3       : AppColors.lightT3;
  Color get _border  => isDark ? AppColors.darkBorder   : AppColors.lightBorder;
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

  // Attempt 1: standard Profile.update() — works for valid Clash YAML subs
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

    if (rawBytes == null || rawBytes.isEmpty) {
      throw firstError ?? 'Пустой ответ сервера.';
    }

    final rawText = utf8.decode(rawBytes, allowMalformed: true).trim();

    // Early content-type sniff: reject HTML, JSON error pages, etc.
    if (_looksLikeHtml(rawText)) {
      throw 'Сервер вернул HTML-страницу вместо подписки. '
          'Проверьте ссылку — возможно, токен истёк или ссылка неверна.';
    }
    if (_looksLikeJsonError(rawText)) {
      throw 'Сервер вернул ошибку: ${rawText.length > 200 ? rawText.substring(0, 200) : rawText}';
    }

    final origErr = firstError?.toString() ?? '';
    final isYamlErr = origErr.contains('yaml') || origErr.contains('mapping') ||
        origErr.contains('line ') || origErr.contains('YAML') ||
        origErr.contains('parse');

    // 2a: Clash YAML with unquoted colon values (server names like "City: Name")
    if (_looksLikeClashYaml(rawText)) {
      try {
        final fixed = _fixYamlColonValues(rawText);
        profile = await base.saveFileWithString(fixed);
      } catch (e) {
        // saveFileWithString failed Clash validation — fall through to 2b
        if (profile == null && !_looksConvertible(rawText)) {
          throw 'Ошибка разбора YAML подписки: $e'
              '\n\nСовет: проверьте, что ссылка ведёт на Clash-формат.';
        }
      }
    }

    // 2b: format conversion (base64 proxy list, single URI, etc.)
    if (profile == null) {
      final String yaml;
      try {
        yaml = convertSubscriptionToClashYaml(rawText);
      } catch (e) {
        if (isYamlErr) {
          throw 'Ошибка YAML в подписке (строка с двоеточием не взята в кавычки?): '
              '${firstError.toString().split('\n').first}'
              '\nОшибка конвертации: $e';
        }
        throw firstError ?? e;
      }
      try {
        profile = await base.saveFileWithString(yaml);
      } catch (e) {
        throw 'Конфиг прошёл конвертацию, но не принят ядром: $e'
            '\nИсходная ошибка: $firstError';
      }
    }
  }

  ref.read(profilesProvider.notifier).setProfile(profile!);
  final isFirstProfile = ref.read(currentProfileIdProvider) == null;
  if (isFirstProfile) {
    ref.read(currentProfileIdProvider.notifier).value = profile!.id;
  }
  // Always apply Russia 2026 preset after import so:
  //   - First import: preset is immediately active with default services
  //   - Re-import: preset rules are reapplied (may have been wiped by new profile)
  // applyRussia2026Preset internally calls applyProfileDebounce so no double-apply.
  applyRussia2026Preset(ref);
}

// ─── Content-type sniff helpers ───────────────────────────────────────────────
bool _looksLikeHtml(String s) {
  final lower = s.toLowerCase();
  return lower.startsWith('<!doctype') ||
      lower.startsWith('<html') ||
      (lower.contains('<html') && lower.contains('<head'));
}

bool _looksLikeJsonError(String s) {
  final t = s.trim();
  if (!t.startsWith('{') && !t.startsWith('[')) return false;
  // Quick heuristic: JSON that contains "error" or "message" key
  return t.contains('"error"') || t.contains('"message"') || t.contains('"code"');
}

bool _looksConvertible(String s) =>
    s.contains('vmess://') || s.contains('vless://') ||
    s.contains('ss://') || s.contains('trojan://') ||
    s.contains('hysteria2://') || s.contains('hy2://');

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

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView> {

  @override
  void dispose() { super.dispose(); }

  // ── Pre-flight: check profile loaded before starting VPN ─────────────────
  Future<void> _toggle(bool isOn) async {
    if (!isOn) {
      final profileId = ref.read(currentProfileIdProvider);
      if (profileId == null) {
        _snack(
          '⚠️ Сначала импортируйте подписку. VPN не может запуститься без конфига.',
          error: true,
          dur: const Duration(seconds: 6),
        );
        return;
      }
    }
    try {
      await globalState.appController.updateStatus(!isOn);
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st);
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('VPN configuration') || msg.contains('null or empty') ||
          msg.contains('getAndroidVpnOptions')) {
        _snack(
          '⚠️ Конфиг VPN не загружен. Переимпортируйте подписку.',
          error: true,
          dur: const Duration(seconds: 8),
        );
      } else {
        final display = msg.length > 200 ? '${msg.substring(0, 200)}…' : msg;
        _snack('Ошибка: $display', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false,
      Duration dur = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black87,
          fontWeight: FontWeight.w500)),
      backgroundColor: error ? AppColors.orange : AppColors.lime,
      duration: dur,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Only watch the two values that actually change UI
    final isOn    = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady = ref.watch(initProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    // Static colors — no animation math
    final bg       = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface  = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border   = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri  = isDark ? AppColors.darkT1 : AppColors.lightT1;
    final textSec  = isDark ? AppColors.darkT2 : AppColors.lightT2;
    final textTer  = isDark ? AppColors.darkT3 : AppColors.lightT3;

    // Button state
    final btnColor = isOn ? AppColors.violetDark : AppColors.violet;
    final btnShadow = isOn
        ? [BoxShadow(color: AppColors.lime.withOpacity(0.35), blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 4))]
        : [BoxShadow(color: AppColors.violet.withOpacity(0.30), blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 4))];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(children: [
            const SizedBox(height: 40),

            // ── Header card ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(children: [
                // Rocket icon — static, no CustomPainter blur
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.lime.withOpacity(0.15) : AppColors.violet.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOn ? AppColors.lime.withOpacity(0.40) : AppColors.violet.withOpacity(0.25),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '🚀',
                      style: TextStyle(
                        fontSize: isOn ? 34 : 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Raketa',
                    style: AppFonts.logo(textPri).copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                Text(
                  isOn ? 'Интернет сейчас свободнее' : 'Запустите VPN',
                  style: AppFonts.body(textSec, size: 13),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Status indicator ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOn
                    ? AppColors.lime.withOpacity(0.08)
                    : surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOn
                      ? AppColors.lime.withOpacity(0.30)
                      : border,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.limeText : textTer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isOn ? 'VPN активен' : 'VPN отключён',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isOn ? AppColors.limeText : textSec,
                  ),
                ),
                const Spacer(),
                if (!isReady)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: textTer,
                    ),
                  ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Big connect button ──────────────────────────────────────────
            // STATIC — no AnimationController, no pulse, no glow animation
            // Glow is a static BoxShadow that changes only when isOn changes
            GestureDetector(
              onTap: isReady ? () => _toggle(isOn) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  color: isReady ? btnColor : textTer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isReady ? btnShadow : [],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      key: ValueKey('$isOn$isReady'),
                      isReady ? (isOn ? 'Отключить' : 'Включить') : 'Инициализация…',
                      style: AppFonts.btnPrimary(Colors.white),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Action row ──────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_link_rounded,
                  label: 'Импорт',
                  color: emerald,
                  surface: surface,
                  border: border,
                  textPri: textPri,
                  textSec: textSec,
                  onTap: () => _showImport(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.tune_rounded,
                  label: 'Настройки',
                  color: emerald,
                  surface: surface,
                  border: border,
                  textPri: textPri,
                  textSec: textSec,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsView())),
                ),
              ),
            ]),

            const SizedBox(height: 32),
            Text('Raketa · from pavel with love ♥',
                style: AppFonts.caption(textTer)),
          ]),
        ),
      ),
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
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? ctrl;
    try {
      ctrl = ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(const SnackBar(
        content: Text('Загружаем подписку…',
            style: TextStyle(color: Colors.black87)),
        backgroundColor: AppColors.lime,
        duration: Duration(seconds: 90),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {}

    Object? importError;
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
    } catch (e, st) {
      importError = e;
      await CrashLogger.instance.logError(e, st, context: 'home import');
    } finally {
      try { ctrl?.close(); } catch (_) {}
    }
    if (importError != null) {
      final msg = importError.toString();
      final display = msg.length > 200 ? '${msg.substring(0, 200)}…' : msg;
      _snack('Ошибка: $display', error: true, dur: const Duration(seconds: 8));
    } else {
      _snack('✓ Подписка добавлена');
    }
  }
}

// ── Static action card — no animation, no CustomPainter ──────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color surface;
  final Color border;
  final Color textPri;
  final Color textSec;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.surface,
    required this.border,
    required this.textPri,
    required this.textSec,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: AppFonts.bodyMedium(textPri)),
          ]),
        ),
      ),
    );
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
      content: Text(msg, style: const TextStyle(color: Colors.black)),
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
        _Card(context: context, child: Column(children: [
          _Tile(
            icon: Icons.flag_rounded, label: 'Пресет «Россия 2026»',
            context: context,
            onTap: () {
              applyRussia2026Preset(ref);
              _snack('Пресет применён');
            },
          ),
          _Div(context),
          _Tile(
            icon: Icons.apps_rounded, label: 'Управление сервисами',
            sublabel: 'Что пускать через VPN',
            trailing: Icon(Icons.chevron_right_rounded,
                color: context.textTer, size: 20),
            context: context,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ServicesView())),
          ),
        ])),
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
          _InfoRow(label: 'Приложение', value: 'Raketa', context: context),
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
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? ctrl;
    try {
      ctrl = ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(const SnackBar(
        content: _LoadingRow('Загружаем подписку…'),
        duration: Duration(seconds: 90),
      ));
    } catch (_) {}

    Object? importError;
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
    } catch (e, st) {
      importError = e;
      await CrashLogger.instance.logError(e, st, context: 'settings import');
    } finally {
      try { ctrl?.close(); } catch (_) {}
    }
    if (importError != null) {
      final msg = importError.toString();
      final display = msg.length > 200 ? '${msg.substring(0, 200)}…' : msg;
      _snack('Ошибка: $display', error: true);
    } else {
      _snack('✓ Подписка добавлена');
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
    child: Text(text.toUpperCase(),
        style: AppFonts.fieldLabel(ctx.textTer)),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final BuildContext context;
  const _Card({required this.child, required this.context});
  @override
  Widget build(BuildContext ctx) {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightDivider,
        ),
      ),
      child: child,
    );
  }
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

// ─────────────────────────────────────────────────────────────────────────────
// Services screen — toggle which services go through VPN
// ─────────────────────────────────────────────────────────────────────────────
class ServicesView extends ConsumerStatefulWidget {
  const ServicesView({super.key});
  @override
  ConsumerState<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends ConsumerState<ServicesView> {
  // Current toggle state: serviceId -> bool (true = VPN, false = DIRECT)
  late Map<String, bool> _states;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _states = {
      for (final s in russiaServices) s.id: s.defaultOn,
    };
    // Load saved states from current profile overrideData
    _loadFromProfile();
  }

  void _loadFromProfile() {
    final currentId = ref.read(currentProfileIdProvider);
    if (currentId == null) return;
    final profiles = ref.read(profilesProvider);
    final profile = profiles.getProfile(currentId);
    if (profile == null) return;
    final od = profile.overrideData;
    if (!od.enable) return;
    final ruleValues = od.rule.rules.map((r) => r.value).toSet();
    // Detect which services are enabled by checking if their first domain appears
    // in any rule that is NOT a DIRECT rule. We cannot rely on the literal "PROXY"
    // string here because patchRawConfig substitutes it with the real group name
    // at apply time — the overrideData still stores the original "PROXY" placeholder.
    for (final svc in russiaServices) {
      final firstDomain = svc.domains.first;
      _states[svc.id] = ruleValues.any((r) =>
          r.contains(firstDomain) && !r.endsWith(',DIRECT'));
    }
  }

  void _toggle(String id, bool value) {
    setState(() {
      _states[id] = value;
      _dirty = true;
    });
  }

  void _apply() {
    applyRussia2026Preset(ref, serviceStates: Map.from(_states));
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Настройки применены',
            style: TextStyle(color: Colors.black)),
        backgroundColor: _lime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.textPri,
        elevation: 0,
        title: Text('Сервисы через VPN',
            style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 20, color: context.textPri)),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _apply,
              child: const Text('Применить',
                  style: TextStyle(
                      color: _violet, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(children: [
        // Header description
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _violet.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _violet.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: _violet),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Включённые сервисы идут через VPN. '
              'Российские сайты (.ru) всегда напрямую.',
              style: TextStyle(color: context.textSec, fontSize: 13),
            )),
          ]),
        ),
        const SizedBox(height: 8),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // VPN section
            _SectionHdr('Через VPN', context),
            _Card(
              context: context,
              child: Column(children: [
                for (int i = 0; i < russiaServices.length; i++) ...[
                  if (i > 0) _Div(context),
                  _ServiceTile(
                    service: russiaServices[i],
                    value: _states[russiaServices[i].id] ?? russiaServices[i].defaultOn,
                    onChanged: (v) => _toggle(russiaServices[i].id, v),
                    context: context,
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // Apply button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text('Применить настройки',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: _dirty ? _violet : _violet.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        )),
      ]),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final RussiaService service;
  final bool value;
  final ValueChanged<bool> onChanged;
  final BuildContext context;

  const _ServiceTile({
    required this.service,
    required this.value,
    required this.onChanged,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.violet,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(children: [
        Text(service.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text(service.name,
            style: AppFonts.bodyMedium(context.textPri)),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Text(
          value ? 'Через VPN' : 'Напрямую',
          style: AppFonts.caption(
              value ? AppColors.violet : context.textTer),
        ),
      ),
    );
  }
}



class _RocketPainter extends CustomPainter {
  final bool active;
  const _RocketPainter({required this.active});

  // Brand palette
  static const _emerald = AppColors.violet;
  static const _spring  = Color(0xFFA0E720);
  static const _sky     = AppColors.violetBorder;
  static const _slate   = AppColors.lightT3;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    if (active) {
      // ── Glow halo ─────────────────────────────────────────────────────────
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [_spring.withOpacity(0.28), _emerald.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(
            center: Offset(cx, h * 0.52), radius: w * 0.52))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(cx, h * 0.52), w * 0.52, glowPaint);
    }

    // ── Rocket body ───────────────────────────────────────────────────────
    // Coordinate system: 0,0 top-left, rocket points UP.
    // Body is an elongated teardrop/capsule shape.
    final bodyPath = Path();
    // Nose tip
    bodyPath.moveTo(cx, h * 0.04);
    // Right shoulder curve
    bodyPath.cubicTo(
      cx + w * 0.32, h * 0.10,
      cx + w * 0.30, h * 0.36,
      cx + w * 0.26, h * 0.55,
    );
    // Right fin flare
    bodyPath.lineTo(cx + w * 0.40, h * 0.76);
    bodyPath.lineTo(cx + w * 0.26, h * 0.68);
    // Bottom right
    bodyPath.lineTo(cx + w * 0.22, h * 0.82);
    // Center bottom (nozzle)
    bodyPath.lineTo(cx, h * 0.78);
    // Center bottom (nozzle) left side
    bodyPath.lineTo(cx - w * 0.22, h * 0.82);
    // Left fin flare
    bodyPath.lineTo(cx - w * 0.26, h * 0.68);
    bodyPath.lineTo(cx - w * 0.40, h * 0.76);
    bodyPath.lineTo(cx - w * 0.26, h * 0.55);
    // Left shoulder curve
    bodyPath.cubicTo(
      cx - w * 0.30, h * 0.36,
      cx - w * 0.32, h * 0.10,
      cx, h * 0.04,
    );
    bodyPath.close();

    if (active) {
      // Gradient fill
      final bodyPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_spring, _emerald],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.85))
        ..style = PaintingStyle.fill;
      canvas.drawPath(bodyPath, bodyPaint);

      // Subtle highlight on left edge
      final highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, w * 0.5, h * 0.6))
        ..style = PaintingStyle.fill;
      canvas.drawPath(bodyPath, highlightPaint);
    } else {
      // Inactive: just outline
      final outlinePaint = Paint()
        ..color = _slate
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(bodyPath, outlinePaint);
    }

    // ── Porthole window ───────────────────────────────────────────────────
    final windowCenter = Offset(cx, h * 0.35);
    final windowRadius = w * 0.115;

    if (active) {
      // Sky-blue filled circle
      canvas.drawCircle(
          windowCenter, windowRadius,
          Paint()..color = _sky.withOpacity(0.95));
      // Sheen
      canvas.drawCircle(
          windowCenter, windowRadius,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [Colors.white.withOpacity(0.4), Colors.transparent],
            ).createShader(Rect.fromCircle(
                center: windowCenter, radius: windowRadius)));
      // Ring
      canvas.drawCircle(
          windowCenter, windowRadius,
          Paint()
            ..color = Colors.white.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.025);
    } else {
      canvas.drawCircle(
          windowCenter, windowRadius,
          Paint()
            ..color = _slate.withOpacity(0.3)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          windowCenter, windowRadius,
          Paint()
            ..color = _slate
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.035);
    }

    // ── Flame exhaust ──────────────────────────────────────────────────────
    if (active) {
      // Outer flame — spring yellow/lime
      final flame1 = Path();
      flame1.moveTo(cx - w * 0.13, h * 0.80);
      flame1.cubicTo(
        cx - w * 0.09, h * 0.90, cx - w * 0.05, h * 1.00, cx, h * 0.97,
      );
      flame1.cubicTo(
        cx + w * 0.05, h * 1.00, cx + w * 0.09, h * 0.90, cx + w * 0.13, h * 0.80,
      );
      flame1.close();
      canvas.drawPath(
          flame1,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_spring.withOpacity(0.9), _spring.withOpacity(0.0)],
            ).createShader(Rect.fromLTWH(cx - w * 0.14, h * 0.78, w * 0.28, h * 0.24)));

      // Inner flame — sky blue / white core
      final flame2 = Path();
      flame2.moveTo(cx - w * 0.06, h * 0.80);
      flame2.cubicTo(
        cx - w * 0.03, h * 0.88, cx - w * 0.01, h * 0.94, cx, h * 0.93,
      );
      flame2.cubicTo(
        cx + w * 0.01, h * 0.94, cx + w * 0.03, h * 0.88, cx + w * 0.06, h * 0.80,
      );
      flame2.close();
      canvas.drawPath(
          flame2,
          Paint()
            ..color = Colors.white.withOpacity(0.75)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  @override
  bool shouldRepaint(_RocketPainter old) => old.active != active;
}
