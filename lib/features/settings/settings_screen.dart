import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/voltra_services.dart';
import '../../core/health_format.dart';
import '../../core/networking/health_api.dart';
import '../../core/services/health_summary_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/health_state_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/voltra_card.dart';
import '../../services/desktop_link.dart';
import '../../vitals/vitals_service.dart';

/// Connections and diagnostics: the health pipeline, the desktop pairing link
/// and the iOS HealthKit path.
///
/// The pairing UI and the HealthKit panel are the existing working screens,
/// moved here unchanged in behaviour.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _ip;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefilled with the host already paired on this machine. No default is
    // baked in: one developer's home LAN address is not a sensible starting
    // value for anyone else, and the field's helper text says what to enter.
    _ip = TextEditingController(text: desktopLink.host ?? '');
    desktopLink.refreshStatus();
  }

  @override
  void dispose() {
    _ip.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        _healthPipeline(context),
        const SizedBox(height: 18),
        _voice(context),
        const SizedBox(height: 18),
        _desktopPairing(context),
        const SizedBox(height: 18),
        _appleHealth(context),
      ],
    );
  }

  Widget _healthPipeline(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: healthSummary,
      builder: (context, _) {
        final (color, label) = HealthStatusView.chip(
          context,
          healthSummary.status,
        );
        final summary = healthSummary.summary;

        return VoltraCard(
          title: 'Health pipeline',
          icon: Icons.lan_outlined,
          trailing: StatusChip(label: label, color: color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apple Watch  →  Apple Health on iPhone  →  Health Auto Export '
                '→  local Flask server  →  VOLTRA',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              FactRow('Endpoint', '${HealthApi.defaultBaseUrl}/health/summary'),
              FactRow(
                'Latest sample',
                formatDayAndTime(summary?.latestSampleAt),
              ),
              FactRow(
                'Metrics in export',
                formatCount(
                  summary?.availableMetrics.length,
                  'metric',
                  'metrics',
                ),
              ),
              FactRow(
                'Daily history',
                formatCount(healthSummary.series?.daysWithData, 'day', 'days'),
              ),
              FactRow('Source device', healthSummary.sourceLabel),
              if (healthSummary.errorMessage != null) ...[
                const SizedBox(height: 12),
                NoticeBox(
                  color: p.danger,
                  icon: Icons.error_outline,
                  text: healthSummary.errorMessage!,
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'The server listens on the LAN so the iPhone can post to it, '
                'but VOLTRA reads it over loopback. Health data stays on this '
                'machine and is never sent anywhere.',
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: healthSummary.isRefreshing
                    ? null
                    : healthSummary.refresh,
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Refresh now'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _desktopPairing(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: desktopLink,
      builder: (context, _) {
        final busy = desktopLink.state == DesktopState.busy;
        final (color, text) = switch (desktopLink.state) {
          DesktopState.online => (p.positive, 'ONLINE'),
          DesktopState.offline => (p.danger, 'OFFLINE'),
          DesktopState.busy => (p.warning, 'WORKING'),
          DesktopState.unknown => (p.textSecondary, 'UNKNOWN'),
          DesktopState.notPaired => (p.textMuted, 'NOT PAIRED'),
        };

        return VoltraCard(
          title: 'VOLTRA Desktop link',
          icon: Icons.computer_outlined,
          trailing: StatusChip(label: text, color: color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                desktopLink.message,
                style: TextStyle(color: p.textSecondary, fontSize: 12.5),
              ),
              if (desktopLink.isPaired) ...[
                const SizedBox(height: 10),
                FactRow('Device', desktopLink.deviceName ?? 'VOLTRA Desktop'),
                FactRow('Address', desktopLink.baseUrl),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _ip,
                decoration: const InputDecoration(
                  labelText: 'Desktop IP',
                  helperText:
                      'LAN IPv4 of the PC running the pairing server '
                      '(port 8765)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Pair code',
                  helperText: 'Not stored on this device',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await desktopLink.pair(
                              host: _ip.text,
                              code: _code.text,
                            );
                            if (ok) _code.clear();
                          },
                    icon: const Icon(Icons.link, size: 17),
                    label: const Text('Pair'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !desktopLink.isPaired
                        ? null
                        : desktopLink.reconnect,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Reconnect'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !desktopLink.isPaired
                        ? null
                        : desktopLink.disconnect,
                    icon: const Icon(Icons.link_off, size: 17),
                    label: const Text('Disconnect'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// The voice panel: whether VOLTRA can speak, which voice it uses, and the
  /// truth about what this machine has installed.
  ///
  /// The language note is here on purpose. Ali writes in Arabic and VOLTRA
  /// answers in English out loud, and the reason is a fact about this PC, not a
  /// preference — so it is stated rather than left as a mystery.
  Widget _voice(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: voiceOut,
      builder: (context, _) {
        final capability = voiceOut.capability;
        final status = voiceOut.status;
        final color = status.canSpeak
            ? p.positive
            : status.isProblem
            ? p.warning
            : p.textMuted;

        return VoltraCard(
          title: 'VOLTRA\'s voice',
          icon: Icons.record_voice_over_outlined,
          trailing: StatusChip(label: status.label, color: color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (voiceOut.problem case final problem?)
                NoticeBox(
                  color: p.warning,
                  icon: Icons.volume_off_outlined,
                  text: problem,
                ),
              Text(
                'VOLTRA reads the morning briefing out loud through the '
                'speech voices built into Windows. It speaks English, because '
                'those are the only voices installed on this PC — there is no '
                'Arabic voice here, and VOLTRA will not write Arabic in Latin '
                'letters to pretend otherwise.',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: voiceOut.enabled,
                onChanged: (value) => voiceOut.setEnabled(value),
                title: Text(
                  'Speak the morning briefing',
                  style: TextStyle(color: p.textPrimary, fontSize: 13.5),
                ),
                subtitle: Text(
                  voiceOut.enabled
                      ? 'The briefing is said out loud once, after you wake up.'
                      : 'The briefing still appears on Home, silently.',
                  style: TextStyle(color: p.textMuted, fontSize: 11.5),
                ),
              ),
              const SizedBox(height: 6),
              FactRow('Engine', voiceOut.engineName),
              FactRow('Voice in use', capability.selected?.readable ?? noData),
              FactRow(
                'Voices installed',
                capability.voices.isEmpty
                    ? noData
                    : capability.voices.map((v) => v.name).join(', '),
              ),
              FactRow(
                'English voices',
                formatCount(capability.englishVoices.length, 'voice', 'voices'),
              ),
              FactRow(
                'Last spoken',
                voiceOut.lastSpokenAt == null
                    ? noData
                    : formatDayAndTime(voiceOut.lastSpokenAt),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: status == VoiceStatus.checking
                        ? null
                        : voiceOut.initialize,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Re-check voices'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed:
                        voiceOut.willSpeak && status != VoiceStatus.speaking
                        ? () => voiceOut.speak(
                            'This is VOLTRA. If you can hear this, the voice '
                            'is working.',
                          )
                        : null,
                    icon: const Icon(Icons.volume_up_outlined, size: 17),
                    label: const Text('Test the voice'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// The enum name ("notDetermined") is not something to put on a screen.
  static String _accessLabel(VitalsAccess access) => switch (access) {
    VitalsAccess.granted => 'Granted',
    VitalsAccess.denied => 'Denied',
    VitalsAccess.notDetermined => 'Not asked yet',
    VitalsAccess.unsupported => 'Not supported on this platform',
  };

  Widget _appleHealth(BuildContext context) {
    final p = context.palette;
    final platform = kIsWeb ? 'Web (Chrome)' : defaultTargetPlatform.name;

    return ListenableBuilder(
      listenable: vitalsService,
      builder: (context, _) {
        final real = vitalsService.usesRealSource;
        final granted = vitalsService.access == VitalsAccess.granted;

        return VoltraCard(
          title: 'Apple HealthKit (iOS build only)',
          icon: Icons.favorite_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                real
                    ? (granted
                          ? 'HealthKit is connected and readable.'
                          : 'HealthKit access has not been granted yet.')
                    : 'HealthKit runs only on a real iPhone, so it is not '
                          'available on $platform. This is not a problem: '
                          'VOLTRA gets your Apple Watch data through the Health '
                          'Auto Export pipeline above instead.',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              FactRow('Platform', platform),
              FactRow('Vitals source', vitalsService.provider.displayName),
              FactRow('Access', _accessLabel(vitalsService.access)),
              if (real) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: vitalsService.loading
                      ? null
                      : vitalsService.requestAccessAndRefresh,
                  icon: const Icon(Icons.health_and_safety, size: 17),
                  label: const Text('Connect Apple Health'),
                ),
              ],
              if (vitalsService.error != null) ...[
                const SizedBox(height: 12),
                NoticeBox(
                  color: p.danger,
                  icon: Icons.error_outline,
                  text: vitalsService.error!,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
