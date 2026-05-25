// ignore_for_file: unused_import
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/russia_preset.dart';
import 'package:flclashx/core/crash_logger.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/theme/app_theme.dart';
import 'package:flclashx/views/profiles/profiles.dart';
import 'package:flclashx/views/proxies/proxies.dart';
import 'package:flclashx/views/service_toggles.dart';
import 'package:flclashx/views/subscription_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kSnackDur    = Duration(seconds: 4);
const _kToggleDur   = Duration(milliseconds: 300);
const _kPulseDur    = Duration(milliseconds: 1400);
const _kSpringCurve = Curves.easeOutCubic;

// ─── doProfileImport (shared top-level) ──────────────────────────────────────
Future<void> doProfileImport({
  required String url,
  required WidgetRef ref,
  required BuildContext context,
  int? depth,
}) async {
  // Prevent infinite redirect loops
  if ((depth ?? 0) > 3) {
    throw 'Слишком много перенаправлений. Проверьте ссылку.';
  }
  if (!globalState.appState.isInit) {
    bool ready = false;
    for (int i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (globalState.appState.isInit) { ready = true; break; }
    }
    if (!ready) throw 'Ядро VPN ещё не готово. Подождите и попробуйте снова.';
  }

  final prefs  = await SharedPreferences.getInstance();
  final sendHd = prefs.getBool('sendDeviceHeaders') ?? true;
  final base   = Profile.normal(url: url);

  Profile? profile;
  Object? firstError;
  try {
    profile = await base
        .update(shouldSendHeaders: sendHd)
        .timeout(const Duration(seconds: 60),
            onTimeout: () => throw 'Превышено время ожидания (60 с).');
  } catch (e) { firstError = e; }

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
    final lower = rawText.toLowerCase();
    final isHtml = lower.startsWith('<!doctype') ||
        lower.startsWith('<html') ||
        (lower.contains('<head') && lower.contains('<body'));

    if (isHtml) {
      // HTML page — try to extract subscription URL or data from it
      final parsed = parseHtmlSubscriptionPage(rawText, pageUrl: url);
      if (parsed.failed) {
        throw parsed.errorReason ?? 'Сервер вернул HTML без данных подписки.';
      }
      if (parsed.hasUrl) {
        // Found a redirect URL — recurse once (depth-limited)
        return doProfileImport(
          url: parsed.subscriptionUrl!,
          ref: ref,
          context: context,
          depth: (depth ?? 0) + 1,
        );
      }
      // Has inline subscription data
      try {
        final yaml = convertSubscriptionToClashYaml(parsed.subscriptionData!);
        profile = await base.saveFileWithString(yaml);
      } catch (e) { throw 'Ошибка обработки подписки из HTML: $e'; }
    } else {
      try {
        final yaml = convertSubscriptionToClashYaml(rawText);
        profile = await base.saveFileWithString(yaml);
      } catch (e) { throw 'Ошибка обработки подписки: $e'; }
    }
  }

  ref.read(profilesProvider.notifier).setProfile(profile!);
  if (ref.read(currentProfileIdProvider) == null) {
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }
  applyRussia2026Preset(ref);
}

// ─────────────────────────────────────────────────────────────────────────────
// ImportDialog
// ─────────────────────────────────────────────────────────────────────────────
class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key, required this.onImport});
  final Future<void> Function(String url) onImport;

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _ctrl    = TextEditingController();
  bool  _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _loading = true);
    try { await widget.onImport(url); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final isDark = context.isDark;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Импорт подписки',
                style: AppFonts.heading(cs.onSurface)),
            const SizedBox(height: 4),
            Text('Вставьте ссылку YAML-подписки',
                style: AppFonts.body(cs.onSurfaceVariant, size: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: AppFonts.body(cs.onSurface),
              decoration: InputDecoration(
                hintText: 'https://',
                hintStyle: AppFonts.body(cs.outline),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  child: Text('Отмена',
                      style: AppFonts.btnGhost(cs.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                if (_loading)
                  SizedBox(
                    width: 36, height: 36,
                    child: Center(child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary)),
                  )
                else
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Добавить'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SettingsView  (3 tabs)
// ─────────────────────────────────────────────────────────────────────────────
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = context.isDark;
    final bg      = isDark ? AppColors.darkBg : AppColors.lightBg;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Настройки', style: AppFonts.heading(cs.onSurface)),
          bottom: TabBar(
            indicatorColor: cs.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Подписки'),
              Tab(text: 'Серверы'),
              Tab(text: 'Сервисы'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProfilesView(),
            ProxiesView(),
            ServiceTogglesView(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SimpleHomeView  — Material Expressive 3 / Android 17 style
// ─────────────────────────────────────────────────────────────────────────────
class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});

  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView>
    with TickerProviderStateMixin {

  // Pulse ring for active state
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseScale;
  late final Animation<double>   _pulseFade;

  // Button press micro-interaction
  late final AnimationController _pressCtrl;
  late final Animation<double>   _pressScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: _kPulseDur)
      ..repeat(reverse: false);
    _pulseScale = Tween<double>(begin: 0.85, end: 1.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseFade = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool isOn) async {
    if (!isOn && ref.read(currentProfileIdProvider) == null) {
      _snack('⚠️ Сначала импортируйте подписку.', error: true);
      return;
    }
    try {
      await globalState.appController.updateStatus(!isOn);
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st);
      final msg = e.toString();
      _snack(msg.length > 200 ? '${msg.substring(0, 200)}…' : msg, error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: cs.onPrimary,
          fontWeight: FontWeight.w500)),
      backgroundColor: error ? cs.error : cs.primary,
      duration: _kSnackDur,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  void _showImport(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (_) => ImportDialog(
        onImport: (url) async {
          Navigator.of(ctx).pop();
          await _runImport(ctx, url);
        },
      ),
    );
  }

  Future<void> _runImport(BuildContext ctx, String url) async {
    _snack('Загружаем подписку…');
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
      _snack('✅ Подписка обновлена!');
    } catch (e) {
      final msg = e.toString();
      _snack(msg.length > 200 ? '${msg.substring(0, 200)}…' : msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn    = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady = ref.watch(initProvider);
    final cs      = Theme.of(context).colorScheme;
    final isDark  = context.isDark;

    // Stop pulse when VPN is off
    if (isOn && !_pulseCtrl.isAnimating) _pulseCtrl.repeat();
    if (!isOn && _pulseCtrl.isAnimating) { _pulseCtrl.stop(); _pulseCtrl.reset(); }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Logo ──────────────────────────────────────────────
              Center(
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'Raketa',
                      style: AppFonts.logo(cs.onSurface)
                          .copyWith(fontSize: 28),
                    ),
                    TextSpan(
                      text: ' VPN',
                      style: AppFonts.logo(cs.primary)
                          .copyWith(fontSize: 28),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 40),

              // ── Hero: animated VPN orb ────────────────────────────────
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring (only when active)
                    if (isOn)
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: _pulseScale.value,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cs.primary.withValues(
                                    alpha: _pulseFade.value),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Middle ring
                    AnimatedContainer(
                      duration: _kToggleDur,
                      curve: _kSpringCurve,
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                      ),
                    ),

                    // Inner button
                    GestureDetector(
                      onTapDown: isReady ? (_) => _pressCtrl.forward() : null,
                      onTapUp: isReady ? (_) async {
                        await _pressCtrl.reverse();
                        await _toggle(isOn);
                      } : null,
                      onTapCancel: isReady ? () => _pressCtrl.reverse() : null,
                      child: AnimatedBuilder(
                        animation: _pressScale,
                        builder: (_, child) => Transform.scale(
                          scale: _pressScale.value,
                          child: child,
                        ),
                        child: AnimatedContainer(
                          duration: _kToggleDur,
                          curve: _kSpringCurve,
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isReady
                                ? (isOn ? cs.primary : cs.primaryContainer)
                                : cs.surfaceContainerHighest,
                            boxShadow: isReady && isOn
                                ? [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.45),
                                      blurRadius: 32,
                                      spreadRadius: 0,
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: _kToggleDur,
                              child: isReady
                                  ? Icon(
                                      isOn
                                          ? Icons.power_settings_new_rounded
                                          : Icons.power_settings_new_rounded,
                                      key: ValueKey<bool>(isOn),
                                      size: 44,
                                      color: isOn
                                          ? cs.onPrimary
                                          : cs.onPrimaryContainer,
                                    )
                                  : SizedBox(
                                      key: const ValueKey<String>('loading'),
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Status chip ───────────────────────────────────────────
              AnimatedContainer(
                duration: _kToggleDur,
                curve: _kSpringCurve,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isOn
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dot indicator
                    AnimatedContainer(
                      duration: _kToggleDur,
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: _kToggleDur,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isOn
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                      child: Text(
                        isOn
                            ? 'Подключено'
                            : (isReady ? 'Нажмите для подключения' : 'Инициализация…'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ── Action cards (M3 ElevatedCard style) ─────────────────
              Row(
                children: [
                  Expanded(
                    child: _M3ActionCard(
                      icon: Icons.add_link_rounded,
                      label: 'Импорт',
                      sublabel: 'Добавить подписку',
                      onTap: () => _showImport(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _M3ActionCard(
                      icon: Icons.tune_rounded,
                      label: 'Настройки',
                      sublabel: 'Серверы и сервисы',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const SettingsView()),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── Footer ────────────────────────────────────────────────
              Text(
                'Raketa · свободный интернет',
                style: AppFonts.caption(cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _M3ActionCard  — Material 3 Expressive card with spring press
// ─────────────────────────────────────────────────────────────────────────────
class _M3ActionCard extends StatefulWidget {
  const _M3ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final IconData    icon;
  final String      label;
  final String      sublabel;
  final VoidCallback onTap;

  @override
  State<_M3ActionCard> createState() => _M3ActionCardState();
}

class _M3ActionCardState extends State<_M3ActionCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async { await _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon,
                    color: cs.onPrimaryContainer, size: 22),
              ),
              const SizedBox(height: 16),
              Text(widget.label,
                  style: AppFonts.bodyMedium(cs.onSurface)),
              const SizedBox(height: 2),
              Text(widget.sublabel,
                  style: AppFonts.body(cs.onSurfaceVariant, size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
