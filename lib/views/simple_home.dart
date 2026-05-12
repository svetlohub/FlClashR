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
const _emerald   = AppColors.violet;
const _emeraldLt = Color(0xFFDDD6FE);
const _spring     = AppColors.lime;
const _springDk   = AppColors.limeDark;
const _sky        = AppColors.violet; 
const _arctic     = AppColors.lime;
const _orange     = AppColors.orange;

// ─────────────────────────────────────────────────────────────────────────────
// Theme helper — delegates to AppColors for consistency
// ─────────────────────────────────────────────────────────────────────────────
extension _ThemeX on BuildContext {
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
  } catch (e) { firstError = e; }

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

    if (rawText.toLowerCase().startsWith('<!doctype') || rawText.toLowerCase().startsWith('<html')) {
      throw 'Сервер вернул HTML вместо подписки. Проверьте ссылку.';
    }

    final String yaml;
    try {
      yaml = convertSubscriptionToClashYaml(rawText);
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
      _snack('Ошибка: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false, Duration dur = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
      backgroundColor: error ? AppColors.orange : AppColors.lime,
      duration: dur,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // --- МЕТОДЫ ИМПОРТА (Которых не хватало) ---
  void _showImport(BuildContext ctx) {
    showDialog<void>(context: ctx,
        builder: (d) => ImportDialog(onImport: (url) async {
          Navigator.of(d).pop();
          await _runImport(ctx, url);
        }));
  }

  Future<void> _runImport(BuildContext ctx, String url) async {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('Загружаем подписку…', style: TextStyle(color: Colors.black87)),
      backgroundColor: AppColors.lime,
      behavior: SnackBarBehavior.floating,
    ));

    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
      _snack('Подписка успешно обновлена!');
    } catch (e) {
      _snack('Ошибка импорта: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn    = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady = ref.watch(initProvider);
    final isDark  = context.isDark;

    final bg        = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface   = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri   = isDark ? AppColors.darkT1 : AppColors.lightT1;
    final textSec   = isDark ? AppColors.darkT2 : AppColors.lightT2;
    final textTer   = isDark ? AppColors.darkT3 : AppColors.lightT3;

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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.lime.withOpacity(0.15) : AppColors.violet.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOn ? AppColors.lime.withOpacity(0.40) : AppColors.violet.withOpacity(0.25),
                    ),
                  ),
                  child: const Center(child: Text('🚀', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(height: 14),
                Text('Raketa', style: AppFonts.logo(textPri).copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                Text(
                  isOn ? 'Интернет сейчас свободнее' : 'Запустите VPN',
                  style: AppFonts.body(textSec, size: 13),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOn ? AppColors.lime.withOpacity(0.08) : surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isOn ? AppColors.lime.withOpacity(0.30) : border),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isOn ? AppColors.limeText : textSec),
                ),
                const Spacer(),
                if (!isReady)
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: textTer)),
              ]),
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: isReady ? () => _toggle(isOn) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  color: isReady ? btnColor : textTer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isReady ? btnShadow : [],
                ),
                child: Center(
                  child: Text(
                    isReady ? (isOn ? 'Отключить' : 'Включить') : 'Инициализация…',
                    style: AppFonts.btnPrimary(Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Row(children: [
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
                      MaterialPageRoute(builder: (_) => const SettingsView())),
                ),
              ),
            ]),

            const SizedBox(height: 32),
            Text('Raketa · from pavel with love ♥', style: AppFonts.caption(textTer)),
          ]),
        ),
      ),
    );
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
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
    );
  }
}
