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

// Kept for backward compat with palette code below — mapped to brand
const _violet    = _emerald;        
const _violetLt  = _emeraldLt;     
const _lime      = _spring;        
const _limeDk    = _springDk;      
const _slate      = AppColors.lightT2;

// ─────────────────────────────────────────────────────────────────────────────
// Theme helper — delegates to AppColors for consistency
// ─────────────────────────────────────────────────────────────────────────────
extension _ThemeX on BuildContext {
  // isDark удален отсюда, так как он есть в BuildContextThemeX (app_theme.dart)
  Color get _bg      => isDark ? AppColors.darkBg        : AppColors.lightBg;
  Color get _surf    => isDark ? AppColors.darkSurface   : AppColors.lightSurface;
  Color get _t1      => isDark ? AppColors.darkT1        : AppColors.lightT1;
  Color get _t2      => isDark ? AppColors.darkT2        : AppColors.lightT2;
  Color get _t3      => isDark ? AppColors.darkT3        : AppColors.lightT3;
  Color get _border  => isDark ? AppColors.darkBorder    : AppColors.lightBorder;
}

// ... (функция doProfileImport и хелперы остаются без изменений до SimpleHomeView)

class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});
  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView> {

  @override
  void dispose() { super.dispose(); }

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
    final isOn    = ref.watch(runTimeProvider.select((t) => t != null));
    final isReady = ref.watch(initProvider);
    // Использование глобального isDark из app_theme.dart
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

            Row(children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_link_rounded,
                  label: 'Импорт',
                  color: AppColors.lime, // Исправлено: заменено emerald
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
                  color: AppColors.lime, // Исправлено: заменено emerald
                  surface: surface,
                  border: border,
                  textPri: textPri,
                  textSec: textSec,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const Scaffold())), // Временная заглушка
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
  
  // ... (остальные методы класса)
}

// Вспомогательный виджет карточки действия
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
