import 'package:flutter/material.dart';

import '../core/context_engine/context_engine.dart';
import '../core/services/voice_service.dart';
import '../core/theme/voltra_theme.dart';
import '../core/widgets/health_state_view.dart';
import '../core/widgets/voltra_card.dart';
import '../features/chat/chat_screen.dart';
import '../features/health/health_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/training/training_screen.dart';
import 'voltra_modules.dart';
import 'voltra_services.dart';

/// The frame VOLTRA lives in: permanent side navigation on the left, the
/// active module on the right.
///
/// The modules are pages of one product, not separate apps — they share this
/// frame, the palette, the health service and the context engine.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  VoltraModule _active = VoltraModule.home;

  @override
  void initState() {
    super.initState();
    desktopLink.refreshStatus();
    healthSummary.refresh();
    healthSummary.startPolling();
  }

  @override
  void dispose() {
    healthSummary.stopPolling();
    super.dispose();
  }

  void _open(VoltraModule module) {
    if (_active == module) return;
    setState(() => _active = module);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final gradient = p.backgroundGradient;

    return Scaffold(
      // The wash lives here, behind every module at once, so Morning Mode is
      // one change of light rather than eight screens each doing their own
      // thing. Palettes without a gradient fall back to the flat background.
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: p.background,
          gradient: gradient == null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
        ),
        child: Row(
          children: [
            if (wide)
              _SideNav(active: _active, onSelect: _open)
            else
              _RailNav(active: _active, onSelect: _open),
            Container(width: 1, color: p.border),
            Expanded(
              child: Column(
                children: [
                  _TopBar(module: _active),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_active) {
      VoltraModule.home => HomeScreen(onOpenModule: _open),
      VoltraModule.health => const HealthScreen(),
      VoltraModule.sleep => const SleepScreen(),
      VoltraModule.training => const TrainingScreen(),
      VoltraModule.schedule => const ScheduleScreen(),
      VoltraModule.insights => const InsightsScreen(),
      VoltraModule.chat => const ChatScreen(),
      VoltraModule.settings => const SettingsScreen(),
    };
  }
}

/// Full side navigation, used on a desktop-sized window.
class _SideNav extends StatelessWidget {
  const _SideNav({required this.active, required this.onSelect});

  final VoltraModule active;
  final ValueChanged<VoltraModule> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: 218,
      color: p.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 4),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'VOLTRA',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.6,
                  ),
                ),
              ],
            ),
          ),
          const _ContextLine(),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final module in VoltraModule.values)
                  _NavItem(
                    module: module,
                    selected: module == active,
                    onTap: () => onSelect(module),
                  ),
              ],
            ),
          ),
          const _HealthPulse(),
        ],
      ),
    );
  }
}

/// Icon-only navigation for narrow windows.
class _RailNav extends StatelessWidget {
  const _RailNav({required this.active, required this.onSelect});

  final VoltraModule active;
  final ValueChanged<VoltraModule> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: 62,
      color: p.surface,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              children: [
                for (final module in VoltraModule.values)
                  Tooltip(
                    message: module.label,
                    child: GestureDetector(
                      onTap: () => onSelect(module),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: module == active
                              ? p.accent.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          module.icon,
                          size: 19,
                          color: module == active ? p.accent : p.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final VoltraModule module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? p.accent.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              module.icon,
              size: 18,
              color: selected ? p.accent : p.textMuted,
            ),
            const SizedBox(width: 12),
            Text(
              module.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? p.textPrimary : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The current context state, shown under the wordmark.
class _ContextLine extends StatelessWidget {
  const _ContextLine();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: contextEngine,
      builder: (context, _) {
        final snapshot = contextEngine.snapshot;
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
          child: Text(
            '${snapshot.phase.label} · ${snapshot.activity.label}',
            style: TextStyle(
              color: p.textMuted,
              fontSize: 9.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

/// Live status of the health link, always visible at the bottom of the nav.
class _HealthPulse extends StatelessWidget {
  const _HealthPulse();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: healthSummary,
      builder: (context, _) {
        final (color, label) = HealthStatusView.chip(
          context,
          healthSummary.status,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Says out loud — on screen — when VOLTRA cannot speak.
///
/// Silence is the one failure a voice assistant can hide completely, so it gets
/// a permanent spot in the top bar rather than a line buried in Settings. When
/// the voice is working this shows nothing: a working feature does not need a
/// badge.
class _VoiceIndicator extends StatelessWidget {
  const _VoiceIndicator();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: voiceOut,
      builder: (context, _) {
        if (voiceOut.status == VoiceStatus.speaking) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                Icon(Icons.graphic_eq, size: 15, color: p.accent),
                const SizedBox(width: 7),
                StatusChip(label: 'SPEAKING', color: p.accent),
              ],
            ),
          );
        }

        final problem = voiceOut.problem;
        if (problem == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Tooltip(
            message: problem,
            child: Row(
              children: [
                Icon(Icons.volume_off_outlined, size: 15, color: p.warning),
                const SizedBox(width: 7),
                StatusChip(label: voiceOut.status.label, color: p.warning),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Module title plus the one control that belongs on every screen: refresh.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.module});

  final VoltraModule module;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Text(module.label, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          const _VoiceIndicator(),
          ListenableBuilder(
            listenable: healthSummary,
            builder: (context, _) {
              final (color, label) = HealthStatusView.chip(
                context,
                healthSummary.status,
              );
              return Row(
                children: [
                  StatusChip(label: label, color: color),
                  const SizedBox(width: 10),
                  if (healthSummary.isRefreshing)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.textMuted,
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Refresh health data',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        healthSummary.refresh();
                        desktopLink.refreshStatus();
                      },
                      icon: Icon(
                        Icons.refresh,
                        size: 18,
                        color: p.textSecondary,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
