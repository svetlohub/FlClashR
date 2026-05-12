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
import 'package:flclashx/views/about.dart';
import 'package:flclashx/views/profiles/profiles.dart';
import 'package:flclashx/views/proxies/proxies.dart';
import 'package:flclashx/views/subscription_converter.dart';
import 'package:flclashx/views/settings_view.dart';
import 'package:flclashx/views/import_dialog.dart';
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
      unawaited(globalState.appController.updateStatus(!isOn));
    } catch (e, st) {
      unawaited(CrashLogger.instance.logError(e, st));
      _snack('Ошибка: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
      backgroundColor: error ? AppColors.orange : AppColors.lime,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showImport(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (d) => ImportDialog(onImport: (url) async {
        Navigator.of(d).pop();
        await _runImport(ctx, url);
      }),
    );
  }

  Future<void> _runImport(BuildContext ctx, String url) async {
    _snack('Загружаем подписку…');
    try {
      await doProfileImport(url: url, ref: ref, context: ctx);
      _snack('Подписка успешно обновлена!');
    } catch (e) {
      _snack('Ошибка импорта: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady = ref.watch(initProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkT1 : AppColors.lightT1;
    final textSec = isDark ? AppColors.darkT2 : AppColors.lightT2;
    final textTer = isDark ? AppColors.darkT3 : AppColors.lightT3;

    final btnColor = isOn ? AppColors.violetDark : AppColors.violet;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(_kRadius),
                border: Border.all(color: border),
              ),
              child: Column(children: [
                Container(
                  width: _kLogoBoxSize,
                  height: _kLogoBoxSize,
                  decoration: BoxDecoration(
                    color: isOn 
                        ? AppColors.lime.withValues(alpha: 0.15) 
                        : AppColors.violet.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(_kLogoBoxRadius),
                  ),
                  child: const Center(child: Text('🚀', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(height: 14),
                Text('Raketa', style: AppFonts.logo(textPri).copyWith(fontSize: 26)),
                Text(isOn ? 'Защищено' : 'Отключено', style: AppFonts.body(textSec, size: 13)),
              ]),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: isReady ? () => _toggle(isOn) : null,
              child: Container(
                width: double.infinity,
                height: _kBtnHeight,
                decoration: BoxDecoration(
                  color: isReady ? btnColor : textTer,
                  borderRadius: BorderRadius.circular(_kRadiusBtn),
                ),
                child: Center(
                  child: Text(
                    isReady ? (isOn ? 'Отключить' : 'Включить') : 'Загрузка…',
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
                  icon: Icons.settings_rounded,
                  label: 'Настройки',
                  color: AppColors.violet,
                  surface: surface,
                  border: border,
                  textPri: textPri,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_kRadiusSm),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
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
    );
  }
}
