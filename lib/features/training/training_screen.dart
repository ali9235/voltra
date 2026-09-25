import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/voltra_services.dart';
import '../../core/context_engine/context_engine.dart';
import '../../core/health_format.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/health_state_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/voltra_card.dart';

/// Training, shown through the current context.
///
/// VOLTRA has no session tracking yet, so this screen does not pretend to
/// know about workouts that were never logged. What it does have is real:
/// the readiness signals from the Apple Watch, and a working rest timer.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  static const List<int> _presets = [60, 90, 120, 180];

  Timer? _timer;
  int _remaining = 0;
  int _selected = 90;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(int seconds) {
    _timer?.cancel();
    setState(() {
      _selected = seconds;
      _remaining = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _remaining = 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([healthSummary, contextEngine]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          children: [
            Text('Training', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            _readiness(context),
            const SizedBox(height: 18),
            _todaysSession(context),
            const SizedBox(height: 18),
            _restTimer(context),
          ],
        );
      },
    );
  }

  /// PRE_WORKOUT view: what his body is saying before he trains. Real data
  /// only — each missing value explains itself.
  Widget _readiness(BuildContext context) {
    final p = context.palette;
    final summary = healthSummary.summary;

    if (!healthSummary.hasData || summary == null) {
      return HealthStatusView.placeholder(context, healthSummary);
    }

    final o = summary.overview;
    final sleep = o.sleep;

    return VoltraCard(
      title: 'Readiness',
      icon: Icons.bolt_outlined,
      trailing: Text(
        contextEngine.snapshot.activity.label,
        style: TextStyle(
          color: p.textMuted,
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...HealthStatusView.notices(context, healthSummary),
          MetricGrid(
            tiles: [
              MetricTile(
                label: 'Sleep',
                value: formatHours(sleep?.totalSleepHours),
                emphasis: true,
                context1: sleep?.sevenDayAverageSleepHours != null
                    ? '7-day avg ${formatHours(sleep!.sevenDayAverageSleepHours)}'
                    : null,
                missingReason: 'no night recorded in this export',
              ),
              MetricTile(
                label: 'HRV',
                value: formatMs(o.hrv?.latest),
                emphasis: true,
                context1: o.hrv?.sevenDayAverage != null
                    ? '7-day avg ${formatMs(o.hrv!.sevenDayAverage)}'
                    : null,
                missingReason: 'not recorded in this export',
              ),
              MetricTile(
                label: 'Resting HR',
                value: formatBpm(o.restingHeartRate?.latest),
                emphasis: true,
                context1: o.restingHeartRate?.sevenDayAverage != null
                    ? '7-day avg ${formatBpm(o.restingHeartRate!.sevenDayAverage)}'
                    : null,
                missingReason: 'not recorded in this export',
              ),
              MetricTile(
                label: 'Exercise today',
                value: formatMinutes(o.exerciseTime?.todayTotal),
                emphasis: true,
                context1: o.exerciseTime?.sevenDayTotal != null
                    ? '${formatMinutes(o.exerciseTime!.sevenDayTotal)} this week'
                    : null,
                missingReason: 'no exercise minutes today yet',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._readingLines(context),
        ],
      ),
    );
  }

  /// Observations, not instructions. VOLTRA reports what changed against his
  /// own baseline and leaves the decision to him.
  List<Widget> _readingLines(BuildContext context) {
    final p = context.palette;
    final o = healthSummary.summary?.overview;
    if (o == null) return const [];

    final lines = <Widget>[];

    final sleepHours = o.sleep?.totalSleepHours;
    final sleepAvg = o.sleep?.sevenDayAverageSleepHours;
    if (sleepHours != null && sleepAvg != null) {
      final deltaMin = ((sleepHours - sleepAvg) * 60).round();
      if (deltaMin <= -45) {
        lines.add(
          ReadingLine(
            'You slept ${formatHours(sleepHours)}, well under your usual '
            '${formatHours(sleepAvg)}. Worth keeping intensity modest today.',
            tone: p.warning,
          ),
        );
      } else if (deltaMin >= 20) {
        lines.add(
          ReadingLine(
            'You slept ${formatHours(sleepHours)}, above your usual '
            '${formatHours(sleepAvg)}.',
            tone: p.positive,
          ),
        );
      }
    }

    final rhr = o.restingHeartRate?.latest;
    final rhrAvg = o.restingHeartRate?.sevenDayAverage;
    if (rhr != null && rhrAvg != null && rhr - rhrAvg >= 4) {
      lines.add(
        ReadingLine(
          'Resting heart rate is ${(rhr - rhrAvg).round()} bpm above your '
          'baseline of ${rhrAvg.round()}.',
          tone: p.warning,
        ),
      );
    }

    if (lines.isEmpty) {
      lines.add(
        ReadingLine(
          'Nothing in your recent data stands out from your usual range.',
          tone: p.accent,
        ),
      );
    }

    return lines;
  }

  Widget _todaysSession(BuildContext context) {
    final p = context.palette;

    return VoltraCard(
      title: "Today's session",
      icon: Icons.fitness_center_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No workout is planned for today.',
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'VOLTRA does not have a workout log yet, so it is not showing '
            'exercises, sets or personal records it has never been given. '
            'Add a training block in Schedule and it will appear here.',
            style: TextStyle(color: p.textMuted, fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _restTimer(BuildContext context) {
    final p = context.palette;
    final running = _remaining > 0;
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;

    return VoltraCard(
      title: 'Rest timer',
      icon: Icons.timer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            running
                ? '$minutes:${seconds.toString().padLeft(2, "0")}'
                : '${_selected ~/ 60}:${(_selected % 60).toString().padLeft(2, "0")}',
            style: TextStyle(
              color: running ? p.accent : p.textMuted,
              fontSize: 46,
              height: 1.05,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in _presets)
                OutlinedButton(
                  onPressed: () => _start(preset),
                  child: Text(
                    '${preset ~/ 60}:${(preset % 60).toString().padLeft(2, "0")}',
                  ),
                ),
              if (running)
                FilledButton(onPressed: _stop, child: const Text('Stop')),
            ],
          ),
        ],
      ),
    );
  }
}
