import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/russia_preset.dart';
import 'package:flclashx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── SharedPreferences key ────────────────────────────────────────────────────
const _kPrefix = 'svc_toggle_';

// ─── Provider ─────────────────────────────────────────────────────────────────
final serviceStatesProvider =
    StateNotifierProvider<ServiceStatesNotifier, Map<String, bool>>((ref) {
  return ServiceStatesNotifier();
});

class ServiceStatesNotifier extends StateNotifier<Map<String, bool>> {
  ServiceStatesNotifier()
      : super({for (final s in russiaServices) s.id: s.defaultOn}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <String, bool>{};
    for (final svc in russiaServices) {
      loaded[svc.id] = prefs.getBool('$_kPrefix${svc.id}') ?? svc.defaultOn;
    }
    state = loaded;
  }

  Future<void> toggle(String id, bool value, WidgetRef ref) async {
    state = {...state, id: value};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPrefix$id', value);
    // Re-apply preset with new service states
    applyRussia2026Preset(ref, serviceStates: state);
  }
}

// ─── View ─────────────────────────────────────────────────────────────────────
class ServiceTogglesView extends ConsumerWidget {
  const ServiceTogglesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states   = ref.watch(serviceStatesProvider);
    final notifier = ref.read(serviceStatesProvider.notifier);
    final isDark   = context.isDark;
    final bg       = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface  = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border   = isDark ? AppColors.darkBorder  : AppColors.lightBorder;
    final textPri  = isDark ? AppColors.darkT1      : AppColors.lightT1;
    final textSec  = isDark ? AppColors.darkT2      : AppColors.lightT2;
    final textTer  = isDark ? AppColors.darkT3      : AppColors.lightT3;

    // Split: enabled by default / disabled by default
    final onByDefault  = russiaServices.where((s) => s.defaultOn).toList();
    final offByDefault = russiaServices.where((s) => !s.defaultOn).toList();

    Widget tile(RussiaService svc) {
      final isOn = states[svc.id] ?? svc.defaultOn;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOn ? AppColors.lime.withValues(alpha: 0.35) : border,
          ),
        ),
        child: SwitchListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Row(
            children: [
              Text(svc.emoji,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(svc.name, style: AppFonts.bodyMedium(textPri)),
            ],
          ),
          value: isOn,
          activeColor: AppColors.limeText,
          activeTrackColor: AppColors.lime.withValues(alpha: 0.45),
          inactiveTrackColor: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
          onChanged: (v) => notifier.toggle(svc.id, v, ref),
        ),
      );
    }

    Widget sectionHeader(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(label, style: AppFonts.caption(textTer)),
        );

    return ColoredBox(
      color: bg,
      child: ListView(
        children: [
          const SizedBox(height: 8),
          sectionHeader('ПО УМОЛЧАНИЮ ЧЕРЕЗ VPN'),
          ...onByDefault.map(tile),
          sectionHeader('МОЖНО ВКЛЮЧИТЬ'),
          ...offByDefault.map(tile),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Весь остальной трафик идёт напрямую (DIRECT).\n'
              'Изменения применяются сразу.',
              style: AppFonts.caption(textTer),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
