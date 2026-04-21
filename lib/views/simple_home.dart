import 'package:flclashx/common/russia_preset.dart';
import 'package:flclashx/controller.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/tools.dart';
import 'package:flclashx/core/crash_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});

  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView>
    with SingleTickerProviderStateMixin {
  static const _bgColor        = Color(0xFF0A0A0A);
  static const _surfaceColor   = Color(0xFF1A1A1A);
  static const _accentGreen    = Color(0xFF00FF9F);
  static const _accentGreenDk  = Color(0xFF00CC7F);
  static const _accentRed      = Color(0xFFFF3B5C);
  static const _accentRedLight = Color(0xFFFF6B81);
  static const _textPrimary    = Color(0xFFFFFFFF);
  static const _textSecondary  = Color(0xFFAAAAAA);
  static const _textTertiary   = Color(0xFF666666);

  late AnimationController _pulse;
  late Animation<double>   _pulseAnim;

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

  // ── VPN toggle ────────────────────────────────────────────
  Future<void> _toggle(bool isStarted) async {
    try {
      await globalState.appController.updateStatus(!isStarted);
    } catch (e, stack) {
      await CrashLogger.instance.logError(e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка VPN: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Preset bottom sheet ───────────────────────────────────
  Future<void> _openModes() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Режимы',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _textPrimary)),
              const SizedBox(height: 8),
              const Text('Выберите готовый набор настроек',
                  style: TextStyle(fontSize: 14, color: _textSecondary)),
              const SizedBox(height: 24),
              _ModeButton(
                icon: Icons.flag_rounded,
                title: 'Россия 2026',
                subtitle: 'YouTube и Telegram через VPN. Банки напрямую.',
                accentColor: _accentRed,
                onTap: () {
                  applyRussia2026Preset(ref);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 12),
              _ModeButton(
                icon: Icons.download_rounded,
                title: 'Импорт ключа',
                subtitle: 'Вставить ссылку на подписку',
                accentColor: _accentGreen,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showImportDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Import dialog ─────────────────────────────────────────
  Future<void> _showImportDialog() async {
    final ctrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Импорт ключа', style: TextStyle(color: _textPrimary)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'Вставьте ссылку',
              hintStyle: const TextStyle(color: _textTertiary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: const Text('Отмена', style: TextStyle(color: _textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: const Text('Импортировать'),
            ),
          ],
        ),
      );
      if (ok == true && ctrl.text.isNotEmpty) {
        await globalState.appController.addProfileFormURL(ctrl.text.trim());
      }
    } finally {
      ctrl.dispose();
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  String _formatRunTime(int? seconds) {
    if (seconds == null) return 'Отключено';
    if (seconds < 60) return 'Подключено (${seconds}с)';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return 'Подключено (${m}м ${s}с)';
    final h = m ~/ 60;
    final mm = m % 60;
    return 'Подключено (${h}ч ${mm}м)';
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isStarted = ref.watch(runTimeProvider.select((t) => t != null));
    final runTime   = ref.watch(runTimeProvider);

    final statusColor  = isStarted ? _accentGreen : _textTertiary;
    final btnColors    = isStarted
        ? [_accentGreenDk, _accentGreen]
        : [_accentRed, _accentRedLight];
    final glowColor    = isStarted
        ? _accentGreen.withOpacity(0.3)
        : _accentRed.withOpacity(0.3);

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 56),
              Icon(
                isStarted ? Icons.shield : Icons.shield_outlined,
                size: 80,
                color: isStarted ? _accentGreen : _textTertiary,
              ),
              const SizedBox(height: 24),
              const Text(
                'FlClashR',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _textPrimary),
              ),
              const Spacer(),
              // ── Big connect/disconnect button ──────────────
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Container(
                  width: double.infinity,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(colors: btnColors),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: isStarted ? 16 + _pulseAnim.value : 12,
                        spreadRadius: isStarted ? _pulseAnim.value : 0,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _toggle(isStarted),
                    child: Center(
                      child: Text(
                        isStarted ? 'Отключить' : 'Включить',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatRunTime(runTime),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _ActionButton(icon: Icons.tune_rounded,     label: 'Режимы',    onTap: _openModes),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.settings_rounded,
                label: 'Настройки',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ToolsView()),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'from pavel with love ♥',
                style: TextStyle(fontSize: 12, color: _textTertiary),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 64,
        child: Material(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: const Color(0xFFAAAAAA)),
                  const SizedBox(width: 16),
                  Text(label, style: const TextStyle(fontSize: 18, color: Colors.white)),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF666666)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  const _ModeButton({
    required this.icon, required this.title, required this.subtitle,
    required this.accentColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 28, color: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
}
