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

// ─── Palette ──────────────────────────────────────────────────────────────────
const _bg        = Color(0xFF0A0A0A);
const _surface   = Color(0xFF1A1A1A);
const _surfaceHi = Color(0xFF252525);
const _green     = Color(0xFF00FF9F);
const _greenDk   = Color(0xFF00CC7F);
const _red       = Color(0xFFFF3B5C);
const _redLt     = Color(0xFFFF6B81);
const _blue      = Color(0xFF00BFFF);
const _textPri   = Color(0xFFFFFFFF);
const _textSec   = Color(0xFFAAAAAA);
const _textTer   = Color(0xFF555555);
const _divider   = Color(0xFF2A2A2A);

// ─────────────────────────────────────────────────────────────────────────────
// Shared import helper
// Supports: Clash YAML, base64-encoded proxy lists, single proxy URIs
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

  // ── Attempt 1: standard Profile.update() — works for Clash YAML subs ──────
  Profile? profile;
  Object? firstError;
  try {
    profile = await base
        .update(shouldSendHeaders: sendHd)
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw 'Превышено время ожидания (60 с). Проверьте ссылку.',
        );
  } catch (e) {
    firstError = e;
  }

  // ── Attempt 2: download raw + fix/convert ─────────────────────────────────
  if (profile == null) {
    Uint8List? rawBytes;
    try {
      final response = await request
          .getFileResponseForUrl(url)
          .timeout(const Duration(seconds: 30));
      rawBytes = response.data;
    } catch (e) {
      throw firstError ?? e;
    }

    if (rawBytes == null || rawBytes.isEmpty) {
      throw firstError ?? 'Сервер вернул пустой ответ.';
    }

    final rawText = utf8.decode(rawBytes, allowMalformed: true).trim();
    final origErr = firstError?.toString() ?? '';
    final isYamlErr = origErr.contains('yaml') ||
        origErr.contains('mapping') ||
        origErr.contains('line ');

    // Step 2a: looks like Clash YAML but has unquoted colons in values
    // (most common cause: proxy names like "DE: Frankfurt" from paid services)
    if (isYamlErr && _looksLikeClashYaml(rawText)) {
      final fixed = _fixYamlColonValues(rawText);
      try {
        profile = await base.saveFileWithString(fixed);
      } catch (_) {
        // still fails — fall through to format conversion
      }
    }

    // Step 2b: format conversion (base64 proxy list, single URI, etc.)
    if (profile == null) {
      final String yamlContent;
      try {
        yamlContent = convertSubscriptionToClashYaml(rawText);
      } catch (convertError) {
        if (isYamlErr) {
          throw 'Не удалось разобрать подписку.\n'
              'Ошибка YAML: $firstError\n'
              'Ошибка конвертации: $convertError';
        }
        throw firstError ?? convertError;
      }
      try {
        profile = await base.saveFileWithString(yamlContent);
      } catch (e) {
        throw 'Конвертация прошла, но конфиг невалидный: $e\n'
            'Исходная ошибка: $firstError';
      }
    }
  }

  ref.read(profilesProvider.notifier).setProfile(profile);
  if (ref.read(currentProfileIdProvider) == null) {
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
    globalState.appController.applyProfileDebounce(silence: true);
  }
}

// ── YAML helpers ─────────────────────────────────────────────────────────────

bool _looksLikeClashYaml(String s) =>
    s.contains('proxies:') ||
    s.contains('proxy-groups:') ||
    s.contains('mixed-port:') ||
    (s.contains('port:') && s.contains('mode:'));

/// Quotes unquoted YAML string values that contain ": " (the main cause of
/// "mapping values are not allowed in this context" errors from Go yaml.v3).
String _fixYamlColonValues(String yaml) {
  return yaml.split('\n').map(_fixYamlLine).join('\n');
}

String _fixYamlLine(String line) {
  final stripped = line.trimLeft();
  if (stripped.isEmpty || stripped.startsWith('#') || stripped.startsWith('---')) {
    return line;
  }
  final m = RegExp(r'^(\s*(?:-\s+)?)(\w[\w\-_.]*)(\s*:\s+)(.+)$').firstMatch(line);
  if (m == null) return line;
  final prefix = m.group(1)!;
  final key    = m.group(2)!;
  final sep    = m.group(3)!;
  final value  = m.group(4)!.trimRight();
  if (!_needsYamlQuoting(value)) return line;
  // Escape backslashes then double-quotes for YAML double-quoted string
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '$prefix$key$sep"$escaped"';
}


bool _needsYamlQuoting(String v) {
  if (v.length >= 2) {
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("\'"))) return false;
  }
  if (RegExp(r'^\d+$').hasMatch(v)) return false;
  if (const {'true', 'false', 'null', '~', '|', '>', '|-', '>-'}.contains(v)) return false;
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
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 8.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool isOn) async {
    try {
      await globalState.appController.updateStatus(!isOn);
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st);
      if (mounted) _snack('Ошибка: $e', error: true);
    }
  }

  String _fmt(int? s) {
    if (s == null) return 'Отключено';
    if (s < 60) return 'Подключено · ${s}с';
    if (s < 3600) return 'Подключено · ${s ~/ 60}м ${s % 60}с';
    return 'Подключено · ${s ~/ 3600}ч ${(s % 3600) ~/ 60}м';
  }

  void _snack(String msg,
      {bool error = false, Duration dur = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _red : _greenDk,
      duration: dur,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isOn    = ref.watch(runTimeProvider.select((t) => t != null));
    final runTime = ref.watch(runTimeProvider);
    final colors  = isOn ? [_greenDk, _green] : [_red, _redLt];
    final glow    = (isOn ? _green : _red).withOpacity(0.28);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const SizedBox(height: 52),
            Icon(isOn ? Icons.shield : Icons.shield_outlined,
                size: 72, color: isOn ? _green : _textTer),
            const SizedBox(height: 16),
            const Text('FlClashR',
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: _textPri,
                    letterSpacing: -1)),
            const Spacer(),

            // ── Big toggle ──────────────────────────────────────────────────
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
                      blurRadius:
                          isOn ? 16 + _pulseAnim.value : 10,
                      spreadRadius:
                          isOn ? _pulseAnim.value * 0.5 : 0,
                    )
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
                          color: _textPri),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(_fmt(runTime),
                style: TextStyle(
                    color: isOn ? _green : _textTer,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const Spacer(),

            // ── Bottom buttons ───────────────────────────────────────────────
            _RowBtn(
                icon: Icons.tune_rounded,
                label: 'Режимы',
                onTap: () => _showModes(context)),
            const SizedBox(height: 10),
            _RowBtn(
                icon: Icons.settings_rounded,
                label: 'Настройки',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SettingsView()))),
            const SizedBox(height: 28),
            const Text('from pavel with love ♥',
                style: TextStyle(fontSize: 11, color: _textTer)),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  void _showModes(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Режимы',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _textPri)),
              const SizedBox(height: 4),
              const Text('Готовый набор правил маршрутизации',
                  style: TextStyle(fontSize: 13, color: _textSec)),
              const SizedBox(height: 20),
              _SheetTile(
                icon: Icons.flag_rounded,
                color: _red,
                title: 'Россия 2026',
                subtitle: 'YouTube, Telegram — VPN. Банки — напрямую.',
                onTap: () {
                  applyRussia2026Preset(ref);
                  Navigator.of(c).pop();
                  _snack('Пресет «Россия 2026» применён');
                },
              ),
              const SizedBox(height: 10),
              _SheetTile(
                icon: Icons.add_link_rounded,
                color: _green,
                title: 'Импорт подписки',
                subtitle: 'Вставить ссылку на прокси-ключ',
                onTap: () {
                  Navigator.of(c).pop();
                  _showImport(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showImport(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (d) => ImportDialog(
        onImport: (url) async {
          Navigator.of(d).pop();
          await _runImport(ctx, url);
        },
      ),
    );
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
      backgroundColor: error ? _red : _greenDk,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final profiles  = ref.watch(profilesProvider);
    final currentId = ref.watch(currentProfileIdProvider);
    final current   = profiles.getProfile(currentId);
    final isReady   = ref.watch(initProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPri,
        elevation: 0,
        title: const Text('Настройки',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [

          // ── Init banner ────────────────────────────────────────────────────
          if (!isReady)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1200),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.amber)),
                SizedBox(width: 12),
                Expanded(
                    child: Text(
                  'Ядро VPN инициализируется. Подождите перед добавлением подписки.',
                  style: TextStyle(color: Colors.amber, fontSize: 13),
                )),
              ]),
            ),

          // ── Subscription ───────────────────────────────────────────────────
          const _SectionHdr('Подписка'),
          _Card(
            child: Column(children: [
              if (current != null) ...[
                _InfoRow(label: 'Активная', value: current.label ?? current.id),
                const _Div(),
              ],
              _Tile(
                icon: Icons.add_link_rounded,
                label: 'Добавить подписку',
                sublabel: isReady ? null : 'Ожидание инициализации…',
                onTap: isReady ? () => _showImport(context) : null,
              ),
              if (current != null) ...[
                const _Div(),
                _Tile(
                  icon: Icons.refresh_rounded,
                  label: 'Обновить подписку',
                  onTap: isReady
                      ? () => _updateCurrent(context, current)
                      : null,
                ),
              ],
              if (profiles.isNotEmpty) ...[
                const _Div(),
                _Tile(
                  icon: Icons.list_rounded,
                  label: 'Все подписки (${profiles.length})',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: _textTer, size: 20),
                  onTap: () =>
                      _showProfileList(context, profiles, currentId),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // ── VPN ────────────────────────────────────────────────────────────
          const _SectionHdr('VPN'),
          _Card(
            child: _Tile(
              icon: Icons.flag_rounded,
              label: 'Пресет «Россия 2026»',
              onTap: () {
                applyRussia2026Preset(ref);
                _snack('Пресет применён');
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── Diagnostics ────────────────────────────────────────────────────
          const _SectionHdr('Диагностика'),
          _Card(
            child: Column(children: [
              _Tile(
                icon: Icons.bug_report_outlined,
                label: 'Просмотр лога',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: _textTer, size: 20),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogView())),
              ),
              const _Div(),
              _Tile(
                icon: Icons.delete_outline_rounded,
                label: 'Очистить лог',
                labelColor: _red,
                onTap: () async {
                  await CrashLogger.instance.clearLogs();
                  _snack('Лог очищен');
                },
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── About ──────────────────────────────────────────────────────────
          const _SectionHdr('О приложении'),
          _Card(
            child: Column(children: [
              _InfoRow(label: 'Приложение', value: 'FlClashR'),
              const _Div(),
              _InfoRow(label: 'Версия', value: _version),
            ]),
          ),
        ],
      ),
    );
  }

  void _showImport(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (d) => ImportDialog(
        onImport: (url) async {
          Navigator.of(d).pop();
          await _runImport(ctx, url);
        },
      ),
    );
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
          .update(
              shouldSendHeaders:
                  prefs.getBool('sendDeviceHeaders') ?? true)
          .timeout(const Duration(seconds: 60),
              onTimeout: () =>
                  throw 'Превышено время ожидания');
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

  void _showProfileList(
      BuildContext ctx, List<Profile> list, String? cid) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Подписки',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _textPri)),
              const SizedBox(height: 16),
              ...list.map((p) {
                final active = p.id == cid;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      active
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: active ? _green : _textTer),
                  title: Text(p.label ?? p.id,
                      style: TextStyle(
                          color: active ? _green : _textPri,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  subtitle: p.url.isNotEmpty
                      ? Text(p.url,
                          style: const TextStyle(
                              color: _textTer, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: _textTer, size: 20),
                    onPressed: () {
                      Navigator.of(c).pop();
                      globalState.appController.deleteProfile(p.id);
                    },
                  ),
                  onTap: () {
                    ref.read(currentProfileIdProvider.notifier).value =
                        p.id;
                    globalState.appController
                        .applyProfileDebounce(silence: true);
                    Navigator.of(c).pop();
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
// Log viewer — full screen with copy button
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
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final text = await CrashLogger.instance.readLogs();
    if (!mounted) return;
    setState(() => _log = text.isEmpty ? 'Лог пуст.' : text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
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
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _bg,
      foregroundColor: _textPri,
      elevation: 0,
      title: const Text('Лог ошибок',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Обновить',
          onPressed: _load,
        ),
        IconButton(
          icon: Icon(
            _copied ? Icons.check_rounded : Icons.copy_rounded,
            color: _copied ? _green : _textPri,
          ),
          tooltip: 'Скопировать всё',
          onPressed: _copy,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: _red),
          tooltip: 'Очистить',
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                backgroundColor: _surface,
                title: const Text('Очистить лог?',
                    style: TextStyle(color: _textPri)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(d).pop(false),
                    child: const Text('Отмена',
                        style: TextStyle(color: _textSec)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(d).pop(true),
                    child: const Text('Очистить',
                        style: TextStyle(color: _red)),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await CrashLogger.instance.clearLogs();
              await _load();
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: Column(children: [
      // ── Hint banner ────────────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: _surfaceHi,
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: _blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Нажмите кнопку копирования ↗ и отправьте лог в чат с Claude',
              style: TextStyle(fontSize: 12, color: _textSec),
            ),
          ),
          if (_copied)
            const Text('Скопировано!',
                style: TextStyle(
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.bold)),
        ]),
      ),
      // ── Log text ───────────────────────────────────────────────────────────
      Expanded(
        child: Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              _log,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: _textSec,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.onImport(url);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _surface,
    shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Импорт подписки',
        style:
            TextStyle(color: _textPri, fontWeight: FontWeight.bold)),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        'Вставьте ссылку (vmess://, vless://, ss://, https://…)',
        style: TextStyle(color: _textSec, fontSize: 13),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _ctrl,
        autofocus: true,
        enabled: !_busy,
        style: const TextStyle(color: _textPri, fontSize: 14),
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(
          hintText: 'https://example.com/sub?token=…',
          hintStyle:
              const TextStyle(color: _textTer, fontSize: 13),
          filled: true,
          fillColor: _surfaceHi,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
        onSubmitted: (_) => _submit(),
      ),
    ]),
    actions: [
      TextButton(
        onPressed:
            _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Отмена',
            style: TextStyle(color: _textSec)),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        style:
            FilledButton.styleFrom(backgroundColor: _green),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : const Text('Добавить',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold)),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Atoms
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHdr extends StatelessWidget {
  final String text;
  const _SectionHdr(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textTer,
            letterSpacing: 1.2)),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16)),
    child: child,
  );
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: _divider, indent: 52);
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile(
      {required this.icon,
      required this.label,
      this.sublabel,
      this.labelColor,
      this.trailing,
      this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon,
        color: onTap != null ? _textSec : _textTer, size: 22),
    title: Text(label,
        style: TextStyle(
            color: onTap != null
                ? (labelColor ?? _textPri)
                : _textTer,
            fontSize: 15)),
    subtitle: sublabel != null
        ? Text(sublabel!,
            style:
                const TextStyle(color: _textTer, fontSize: 12))
        : null,
    trailing: trailing,
    onTap: onTap,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16)),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Text(label,
          style:
              const TextStyle(color: _textSec, fontSize: 15)),
      const Spacer(),
      Text(value,
          style:
              const TextStyle(color: _textPri, fontSize: 15)),
    ]),
  );
}

class _RowBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RowBtn(
      {required this.icon,
      required this.label,
      required this.onTap});
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
          padding:
              const EdgeInsets.symmetric(horizontal: 22),
          child: Row(children: [
            Icon(icon, size: 22, color: _textSec),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    fontSize: 17, color: _textPri)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: _textTer, size: 20),
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
  const _SheetTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: _surfaceHi,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textPri)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: _textSec)),
              ])),
          const Icon(Icons.chevron_right_rounded,
              color: _textTer, size: 18),
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
    const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white)),
    const SizedBox(width: 12),
    Text(text),
  ]);
}
