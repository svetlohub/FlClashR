import 'package:flclashx/common/russia_preset.dart';
import 'package:flclashx/controller.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/views/tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimpleHomeView extends ConsumerStatefulWidget {
  const SimpleHomeView({super.key});

  @override
  ConsumerState<SimpleHomeView> createState() => _SimpleHomeViewState();
}

class _SimpleHomeViewState extends ConsumerState<SimpleHomeView>
    with SingleTickerProviderStateMixin {
  static const _bgColor = Color(0xFF0A0A0A);
  static const _surfaceColor = Color(0xFF1A1A1A);
  static const _accentGreen = Color(0xFF00FF9F);
  static const _accentGreenDark = Color(0xFF00CC7F);
  static const _accentRed = Color(0xFFFF3B5C);
  static const _accentRedLight = Color(0xFFFF6B81);
  static const _accentBlue = Color(0xFF00BFFF);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFFAAAAAA);
  static const _textTertiary = Color(0xFF666666);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection(bool isStarted) async {
    await appController.updateStatus(!isStarted);
  }

  Future<void> _openModes() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Режимы',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Выберите готовый набор настроек',
                  style: TextStyle(fontSize: 14, color: _textSecondary),
                ),
                const SizedBox(height: 24),
                _ModeButton(
                  icon: Icons.flag_rounded,
                  title: 'Россия, вперёд!',
                  subtitle: 'YouTube, Telegram через VPN. Банки напрямую.',
                  accentColor: _accentRed,
                  onTap: () {
                    applyRussia2026Preset(ref);
                    Navigator.of(sheetContext).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _surfaceColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        content: const Text(
                          'Режим «Россия» применён ✅',
                          style: TextStyle(color: _textPrimary),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ModeButton(
                  icon: Icons.download_rounded,
                  title: 'Импорт ключа',
                  subtitle: 'Вставить ссылку на подписку',
                  accentColor: _accentGreen,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showImportDialog();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    try {
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Импорт ключа',
              style: TextStyle(color: _textPrimary),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Вставьте ссылку',
                hintStyle: const TextStyle(color: _textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _textTertiary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _accentBlue),
                ),
              ),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _accentBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Импортировать'),
              ),
            ],
          );
        },
      );
      final url = controller.text.trim();
      if (shouldImport != true || url.isEmpty) return;
      await appController.addProfileFormURL(url);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openTools() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ToolsView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStarted = ref.watch(
      runTimeProvider.select((state) => state != null),
    );
    final runTime = ref.watch(runTimeProvider);

    final statusColor = isStarted ? _accentGreen : _textTertiary;
    final buttonColors = isStarted
        ? [_accentGreenDark, _accentGreen]
        : [_accentRed, _accentRedLight];
    final glowColor = isStarted
        ? _accentGreen.withValues(alpha: 0.3)
        : _accentRed.withValues(alpha: 0.3);
    final powerSubtitle = isStarted
        ? (runTime != null ? 'Работает: $runTime сек' : 'Подключено')
        : 'Нажмите для подключения';

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
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Свободный интернет для семьи',
                style: TextStyle(fontSize: 16, color: _textSecondary),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (animCtx, child) {
                  return Container(
                    width: double.infinity,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: buttonColors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius:
                              isStarted ? 16 + _pulseAnimation.value : 12,
                          spreadRadius: isStarted ? _pulseAnimation.value : 0,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _toggleConnection(isStarted),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          isStarted ? 'Отключить' : 'Включить',
                          key: ValueKey(isStarted),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
                child: Text(isStarted ? 'Подключено' : 'Отключено'),
              ),
              const SizedBox(height: 2),
              Text(
                powerSubtitle,
                style: const TextStyle(fontSize: 13, color: _textTertiary),
              ),
              const Spacer(),
              _ActionButton(
                icon: Icons.tune_rounded,
                label: 'Режимы',
                onTap: _openModes,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.settings_rounded,
                label: 'Настройки',
                onTap: _openTools,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Material(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async => await onTap(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(icon, size: 24, color: const Color(0xFFAAAAAA)),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF666666),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF666666),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
