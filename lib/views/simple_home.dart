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
import 'package:flclashx/theme/app_theme.dart';
import 'package:flclashx/views/profiles/profiles.dart';
import 'package:flclashx/views/service_toggles.dart';
import 'package:flclashx/views/proxies/proxies.dart';
import 'package:flclashx/views/subscription_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Layout constants ─────────────────────────────────────────────────────────
const _kRadius        = 16.0;
const _kRadiusSm      = 14.0;
const _kRadiusBtn     = 16.0;
const _kBtnHeight     = 64.0;
const _kLogoBoxSize   = 72.0;
const _kLogoBoxRadius = 20.0;
const _kHPad          = 20.0;
const _kCardPadV      = 28.0;
const _kCardPadH      = 20.0;
const _kToggleDur     = Duration(milliseconds: 220);
const _kPulseDur      = Duration(milliseconds: 1200);
const _kSnackDur      = Duration(seconds: 4);

// ─── Shared import helper ──────────────────────────────────────────────────────
Future<void> doProfileImport({
  required String url,
  required WidgetRef ref,
  required BuildContext context,
}) async {
  if (!globalState.appState.isInit) {
    bool ready = false;
    for (int i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (globalState.appState.isInit) {
        ready = true;
        break;
      }
    }
    if (!ready) {
      throw 'Ядро VPN ещё не готово. Подождите несколько секунд и попробуйте снова.';
    }
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
  } catch (e) {
    firstError = e;
  }

  if (profile == null) {
    Uint8List? rawBytes;
    try {
      final resp = await request
          .getFileResponseForUrl(url)
          .timeout(const Duration(seconds: 30));
      rawBytes = resp.data;
    } catch (e) {
      throw firstError ?? e;
    }

    if (rawBytes == null || rawBytes.isEmpty) {
      throw firstError ?? 'Пустой ответ сервера.';
    }

    final rawText = utf8.decode(rawBytes, allowMalformed: true).trim();

    if (rawText.toLowerCase().startsWith('<!doctype') ||
        rawText.toLowerCase().startsWith('<html')) {
      throw 'Сервер вернул HTML вместо подписки. Проверьте ссылку.';
    }

    try {
      final yaml = convertSubscriptionToClashYaml(rawText);
      profile = await base.saveFileWithString(yaml);
    } catch (e) {
      throw 'Ошибка обработки подписки: $e';
    }
  }

  ref.read(profilesProvider.notifier).setProfile(profile!);
  if (ref.read(currentProfileIdProvider) == null) {
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }
  applyRussia2026Preset(ref);
}

// ─────────────────────────────────────────────────────────────────────────────
// ImportDialog — URL input dialog
// ─────────────────────────────────────────────────────────────────────────────
class ImportDialog extends StatefulWidget {
  final Future<void> Function(String url) onImport;

  const ImportDialog({super.key, required this.onImport});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.onImport(url);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = context.isDark;
    final surface  = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final textPri  = isDark ? AppColors.darkT1       : AppColors.lightT1;
    final textSec  = isDark ? AppColors.darkT2       : AppColors.lightT2;
    final borderC  = isDark ? AppColors.darkBorder   : AppColors.lightBorder;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kRadius)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Импорт подписки', style: AppFonts.heading(textPri)),
            const SizedBox(height: 6),
            Text(
              'Вставьте ссылку на YAML-подписку',
              style: AppFonts.body(textSec, size: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: AppFonts.body(textPri),
              decoration: InputDecoration(
                hintText: 'https://',
                hintStyle: AppFonts.body(
                  isDark ? AppColors.darkT3 : AppColors.lightT3,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderC),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderC),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.violet, width: 2),
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
                  child: Text('Отмена', style: AppFonts.btnGhost(textSec)),
                ),
                const SizedBox(width: 8),
                if (_loading)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.violet),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: Text('Добавить',
                        style: AppFonts.btnPrimary(Colors.white)),
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
// SettingsView — tabbed: Subscriptions · Services
// ─────────────────────────────────────────────────────────────────────────────
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark  = context.isDark;
    final bg      = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final textPri = isDark ? AppColors.darkT1    : AppColors.lightT1;
    final textSec = isDark ? AppColors.darkT2    : AppColors.lightT2;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textPri),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Настройки', style: AppFonts.heading(textPri)),
          bottom: TabBar(
            indicatorColor: AppColors.violet,
            labelColor: AppColors.violet,
            unselectedLabelColor: textSec,
            labelStyle: AppFonts.bodyMedium(AppColors.violet, size: 13),
            unselectedLabelStyle: AppFonts.body(textSec, size: 13),
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
// SimpleHomeView — main screen
// ─────────────────────────────────────────────────────────────────────────────
class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});

  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: _kPulseDur)
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool isOn) async {
    if (!isOn) {
      final profileId = ref.read(currentProfileIdProvider);
      if (profileId == null) {
        _snack('⚠️ Сначала импортируйте подписку.', error: true);
        return;
      }
    }
    try {
      await globalState.appController.updateStatus(!isOn);
    } catch (e, st) {
      await CrashLogger.instance.logError(e, st);
      final msg = e.toString();
      _snack(
        msg.length > 200 ? '${msg.substring(0, 200)}…' : msg,
        error: true,
      );
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(
        msg,
        style: const TextStyle(
            color: Colors.black87, fontWeight: FontWeight.w500),
      ),
      backgroundColor: error ? AppColors.orange : AppColors.lime,
      duration: _kSnackDur,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(const SnackBar(
      content: Text(
        'Загружаем подписку…',
        style: TextStyle(color: Colors.black87),
      ),
      backgroundColor: AppColors.lime,
      behavior: SnackBarBehavior.floating,
    ));
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
      _snack('✅ Подписка успешно обновлена!');
    } catch (e) {
      final msg = e.toString();
      _snack(
        msg.length > 200 ? '${msg.substring(0, 200)}…' : msg,
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn    = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady = ref.watch(initProvider);
    final isDark  = context.isDark;

    final bg      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border  = isDark ? AppColors.darkBorder  : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkT1      : AppColors.lightT1;
    final textSec = isDark ? AppColors.darkT2      : AppColors.lightT2;
    final textTer = isDark ? AppColors.darkT3      : AppColors.lightT3;

    final btnColor  = isOn ? AppColors.violetDark : AppColors.violet;
    final btnShadow = [
      BoxShadow(
        color: (isOn ? AppColors.lime : AppColors.violet)
            .withOpacity(isOn ? 0.35 : 0.30),
        blurRadius: 16,
        spreadRadius: -2,
        offset: const Offset(0, 4),
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(_kHPad, 0, _kHPad, 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Hero card ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: _kCardPadV, horizontal: _kCardPadH),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(_kRadius),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: _kToggleDur,
                      width: _kLogoBoxSize,
                      height: _kLogoBoxSize,
                      decoration: BoxDecoration(
                        color: isOn
                            ? AppColors.lime.withOpacity(0.15)
                            : AppColors.violet.withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(_kLogoBoxRadius),
                        border: Border.all(
                          color: isOn
                              ? AppColors.lime.withOpacity(0.40)
                              : AppColors.violet.withOpacity(0.25),
                        ),
                      ),
                      child: const Center(
                        child: Text('🚀',
                            style: TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Raketa',
                      style:
                          AppFonts.logo(textPri).copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: _kToggleDur,
                      child: Text(
                        isOn
                            ? 'Интернет сейчас свободнее'
                            : 'Запустите VPN',
                        key: ValueKey<bool>(isOn),
                        style: AppFonts.body(textSec, size: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── VPN status row with pulse ──────────────────────────────
              AnimatedContainer(
                duration: _kToggleDur,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppColors.lime.withOpacity(0.08)
                      : surface,
                  borderRadius: BorderRadius.circular(_kRadiusSm),
                  border: Border.all(
                    color: isOn
                        ? AppColors.lime.withOpacity(0.30)
                        : border,
                  ),
                ),
                child: Row(
                  children: [
                    if (isOn)
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.limeText
                                .withOpacity(_pulseAnim.value),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lime.withOpacity(
                                    _pulseAnim.value * 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: textTer, shape: BoxShape.circle),
                      ),
                    const SizedBox(width: 10),
                    AnimatedDefaultTextStyle(
                      duration: _kToggleDur,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isOn ? AppColors.limeText : textSec,
                      ),
                      child: Text(
                          isOn ? 'VPN активен' : 'VPN отключён'),
                    ),
                    const Spacer(),
                    if (!isReady)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: textTer),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Toggle button ──────────────────────────────────────────
              _PressableButton(
                enabled: isReady,
                onTap: () => _toggle(isOn),
                child: AnimatedContainer(
                  duration: _kToggleDur,
                  width: double.infinity,
                  height: _kBtnHeight,
                  decoration: BoxDecoration(
                    color: isReady ? btnColor : textTer,
                    borderRadius: BorderRadius.circular(_kRadiusBtn),
                    boxShadow: isReady ? btnShadow : const [],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: _kToggleDur,
                      child: Text(
                        isReady
                            ? (isOn ? 'Отключить' : 'Включить')
                            : 'Инициализация…',
                        key: ValueKey<String>(
                          isReady
                              ? (isOn ? 'on' : 'off')
                              : 'init',
                        ),
                        style: AppFonts.btnPrimary(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Action cards ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.add_link_rounded,
                      label: 'Импорт',
                      color: AppColors.lime,
                      surface: surface,
                      border: border,
                      textPri: textPri,
                      onTap: () => _showImport(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.tune_rounded,
                      label: 'Настройки',
                      color: AppColors.lime,
                      surface: surface,
                      border: border,
                      textPri: textPri,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsView(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Text(
                'Raketa · from pavel with love ♥',
                style: AppFonts.caption(textTer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PressableButton — scale-on-press micro-interaction
// ─────────────────────────────────────────────────────────────────────────────
class _PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const _PressableButton({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.enabled ? (_) => _ctrl.reverse() : null,
      onTapCancel: widget.enabled ? () => _ctrl.reverse() : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionCard — tappable tile with ripple
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color surface;
  final Color border;
  final Color textPri;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.surface,
    required this.border,
    required this.textPri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(_kRadiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kRadiusSm),
        splashColor: AppColors.violet.withOpacity(0.08),
        highlightColor: AppColors.violet.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kRadiusSm),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(label, style: AppFonts.bodyMedium(textPri)),
            ],
          ),
        ),
      ),
    );
  }
}
