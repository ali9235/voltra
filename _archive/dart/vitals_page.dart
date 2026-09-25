import 'package:flutter/material.dart';

import 'app/voltra_services.dart' show vitalsService;
import 'vitals/vitals_service.dart';

/// VOLTRA // VITALS
///
/// Renders whatever the active provider returns.
///   * Web/Windows  -> demo values, every tile marked DEMO.
///   * iOS          -> Apple Health values, or "NO DATA". Never demo values.
class VitalsPage extends StatefulWidget {
  const VitalsPage({super.key});

  @override
  State<VitalsPage> createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> {
  @override
  void initState() {
    super.initState();
    vitalsService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOLTRA // VITALS'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: vitalsService.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: vitalsService,
        builder: (context, _) {
          final snap = vitalsService.snapshot;

          if (vitalsService.loading && snap == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sourceBanner(),
              if (vitalsService.needsPermission) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: vitalsService.requestAccessAndRefresh,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Grant Apple Health access'),
                ),
              ],
              const SizedBox(height: 14),
              if (snap == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('NO DATA'),
                  ),
                )
              else ...[
                _tile('Sleep', _hours(snap.sleepHours), 'Last night', snap),
                _tile('Steps', _int(snap.steps), 'Today', snap),
                _tile('Resting Heart Rate', _bpm(snap.restingHeartRate),
                    'Latest', snap),
                _tile('Heart Rate', _bpm(snap.heartRate), 'Latest', snap),
                _tile(
                  'Activity',
                  snap.activityPercent == null
                      ? null
                      : '${snap.activityPercent}%',
                  'of ${VitalsSnapshot.stepGoal} step goal',
                  snap,
                ),
                _tile('Workout', _minutes(snap.workoutMinutes), 'Today', snap),
                _tile('Active Energy', _kcal(snap.activeEnergyKcal), 'Today',
                    snap),
                _tile('Distance', _km(snap.distanceMeters), 'Walking + running',
                    snap),
              ],
              const SizedBox(height: 12),
              Text(
                'Source: ${vitalsService.provider.displayName}\n'
                '${vitalsService.provider.statusDescription}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              if (vitalsService.error != null) ...[
                const SizedBox(height: 10),
                Card(
                  color: const Color(0xFF1A0A0A),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      vitalsService.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sourceBanner() {
    final demo = !vitalsService.usesRealSource;
    final live = vitalsService.isRealData &&
        vitalsService.access == VitalsAccess.granted;

    final color = demo
        ? Colors.orangeAccent
        : (live ? Colors.greenAccent : Colors.amberAccent);

    return Card(
      color: demo ? const Color(0xFF1A1206) : const Color(0xFF07160F),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              demo
                  ? Icons.science_outlined
                  : (live ? Icons.verified_outlined : Icons.lock_outline),
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                vitalsService.sourceBanner,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A null [value] renders as "NO DATA" — never as 0, never as a demo number.
  Widget _tile(
    String title,
    String? value,
    String subtitle,
    VitalsSnapshot snap,
  ) {
    final missing = value == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(snap.isDemo ? '$subtitle • DEMO' : subtitle),
        trailing: Text(
          value ?? 'NO DATA',
          style: TextStyle(
            fontSize: missing ? 13 : 18,
            fontWeight: missing ? FontWeight.normal : FontWeight.bold,
            color: missing ? Colors.white38 : null,
          ),
        ),
      ),
    );
  }

  String? _hours(double? v) => v == null ? null : '${v.toStringAsFixed(1)} h';
  String? _bpm(double? v) => v == null ? null : '${v.toStringAsFixed(0)} bpm';
  String? _minutes(int? v) => v == null ? null : '$v min';
  String? _kcal(double? v) => v == null ? null : '${v.toStringAsFixed(0)} kcal';
  String? _km(double? v) =>
      v == null ? null : '${(v / 1000).toStringAsFixed(2)} km';

  String? _int(int? v) {
    if (v == null) return null;
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
