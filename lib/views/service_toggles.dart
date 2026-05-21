import 'package:flclashx/common/common.dart';
import 'package:flclashx/common/russia_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Persistence ──────────────────────────────────────────────────────────────
const _kPrefix = 'svc_toggle_';

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
    final prefs  = await SharedPreferences.getInstance();
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
    applyRussia2026Preset(ref, serviceStates: state);
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────
class ServiceTogglesView extends ConsumerWidget {
  const ServiceTogglesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states   = ref.watch(serviceStatesProvider);
    final notifier = ref.read(serviceStatesProvider.notifier);
    final cs       = Theme.of(context).colorScheme;

    final onByDefault  = russiaServices.where((s) => s.defaultOn).toList();
    final offByDefault = russiaServices.where((s) => !s.defaultOn).toList();

    return ColoredBox(
      color: cs.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SizedBox(height: 4),

          // ── Active by default ──────────────────────────────────────────
          _SectionLabel(
            text: 'Всегда через VPN',
            icon: Icons.rocket_launch_rounded,
            color: cs.primary,
          ),
          const SizedBox(height: 8),
          ...onByDefault.map((svc) => _ServiceTile(
                svc: svc,
                isOn: states[svc.id] ?? svc.defaultOn,
                onToggle: (v) => notifier.toggle(svc.id, v, ref),
              )),

          const SizedBox(height: 20),

          // ── Off by default ─────────────────────────────────────────────
          _SectionLabel(
            text: 'Можно включить',
            icon: Icons.add_circle_outline_rounded,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          ...offByDefault.map((svc) => _ServiceTile(
                svc: svc,
                isOn: states[svc.id] ?? svc.defaultOn,
                onToggle: (v) => notifier.toggle(svc.id, v, ref),
              )),

          const SizedBox(height: 28),

          // ── Footer note ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Весь остальной трафик идёт напрямую (DIRECT). '
                    'Изменения применяются мгновенно.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.icon,
    required this.color,
  });
  final String   text;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Service tile ─────────────────────────────────────────────────────────────
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.svc,
    required this.isOn,
    required this.onToggle,
  });
  final RussiaService        svc;
  final bool                 isOn;
  final ValueChanged<bool>   onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isOn ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: () => onToggle(!isOn),
          borderRadius: BorderRadius.circular(20),
          splashColor: cs.primary.withValues(alpha: 0.08),
          highlightColor: cs.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                // Emoji avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isOn
                        ? cs.primary.withValues(alpha: 0.15)
                        : cs.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(svc.emoji,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        svc.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isOn
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          isOn ? 'Через VPN' : 'Напрямую',
                          key: ValueKey<bool>(isOn),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: isOn
                                ? cs.onPrimaryContainer
                                    .withValues(alpha: 0.7)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Custom toggle pill
                _TogglePill(isOn: isOn, onToggle: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Custom toggle pill (Material Expressive style) ───────────────────────────
class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.isOn, required this.onToggle});
  final bool             isOn;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onToggle(!isOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 30,
        decoration: BoxDecoration(
          color: isOn ? cs.primary : cs.outline.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(15),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isOn ? cs.onPrimary : cs.outline,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              isOn ? Icons.check_rounded : Icons.remove_rounded,
              size: 14,
              color: isOn ? cs.primary : cs.surface,
            ),
          ),
        ),
      ),
    );
  }
}
