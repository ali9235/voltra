import 'package:flutter/material.dart';

import '../../app/voltra_services.dart';
import '../../core/health_format.dart';
import '../../core/services/health_summary_service.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/health_state_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/trend_chart.dart';
import '../../core/widgets/voltra_card.dart';

/// Sleep, phrased the way a person reads it:
/// "7h 25m — 3:11 AM → 11:02 AM — 7-day avg 7h 57m".
///
/// Stages are shown only when the export actually carries them. The current
/// Health Auto Export writes zeros for awake/core/deep/REM, so VOLTRA says so
/// rather than drawing four empty bars.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  HealthRange _range = HealthRange.today;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: healthSummary,
      builder: (context, _) {
        final summary = healthSummary.summary;

        if (!healthSummary.hasData || summary == null) {
          return Padding(
            padding: const EdgeInsets.all(26),
            child: HealthStatusView.placeholder(context, healthSummary),
          );
        }

        final sleep = summary.overview.sleep;
        final series = healthSummary.series?.sleep;

        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sleep',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                RangeSelector(
                  value: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...HealthStatusView.notices(context, healthSummary),
            if (sleep == null)
              VoltraCard(
                child: Text(
                  'No sleep record has arrived in this export. Apple Health '
                  'only writes a night once the Apple Watch has finished '
                  'processing it.',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              )
            else ...[
              _lastNight(context, sleep),
              const SizedBox(height: 18),
              _recovery(context, summary),
              const SizedBox(height: 18),
              _history(context, series),
            ],
            HealthStatusView.sourceFooter(context, healthSummary),
          ],
        );
      },
    );
  }

  Widget _lastNight(BuildContext context, SleepSummary sleep) {
    final p = context.palette;
    final delta = formatSleepDelta(sleep.deltaVsWeeklyAverage);

    return VoltraCard(
      title: 'Last recorded night',
      icon: Icons.bedtime_outlined,
      trailing: sleep.latestDate != null
          ? Text(
              _dateLabel(sleep.latestDate!),
              style: TextStyle(color: p.textMuted, fontSize: 11.5),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatHours(sleep.totalSleepHours),
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 46,
              height: 1.05,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sleep.sleepStart != null && sleep.sleepEnd != null
                ? '${formatClock(sleep.sleepStart)} → ${formatClock(sleep.sleepEnd)}'
                      '${sleep.sevenDayAverageSleepHours != null ? "   ·   7-day avg ${formatHours(sleep.sevenDayAverageSleepHours)}" : ""}'
                : 'Start and end times were not included in this export.',
            style: TextStyle(color: p.textSecondary, fontSize: 14),
          ),
          if (delta != null) ...[
            const SizedBox(height: 14),
            ReadingLine(
              'That is $delta.',
              tone: (sleep.deltaVsWeeklyAverage ?? 0) < -0.33
                  ? p.warning
                  : p.positive,
            ),
          ],
          const SizedBox(height: 16),
          _stages(context, sleep),
        ],
      ),
    );
  }

  /// Stages, or an honest explanation of their absence. Never both.
  Widget _stages(BuildContext context, SleepSummary sleep) {
    final p = context.palette;

    if (!sleep.stagesAvailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.layers_outlined, size: 15, color: p.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sleep stages (awake, core, deep, REM) are not present in this '
                'export, so VOLTRA is not showing a stage breakdown. Total '
                'sleep above is real.',
                style: TextStyle(color: p.textMuted, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    final stages = sleep.stages;
    return MetricGrid(
      spacing: 18,
      tiles: [
        MetricTile(label: 'Deep', value: formatHours(stages.deep), width: 120),
        MetricTile(label: 'REM', value: formatHours(stages.rem), width: 120),
        MetricTile(label: 'Core', value: formatHours(stages.core), width: 120),
        MetricTile(
          label: 'Awake',
          value: formatHours(stages.awake),
          width: 120,
        ),
      ],
    );
  }

  Widget _recovery(BuildContext context, HealthSummary summary) {
    final o = summary.overview;

    return VoltraCard(
      title: 'Overnight recovery signals',
      icon: Icons.monitor_heart_outlined,
      child: MetricGrid(
        tiles: [
          MetricTile(
            label: 'Resting HR',
            value: formatBpm(o.restingHeartRate?.latest),
            emphasis: true,
            context1: o.restingHeartRate?.sevenDayAverage != null
                ? '7-day average ${formatBpm(o.restingHeartRate!.sevenDayAverage)}'
                : null,
            missingReason: 'not recorded in this export',
          ),
          MetricTile(
            label: 'HRV',
            value: formatMs(o.hrv?.latest),
            emphasis: true,
            context1: o.hrv?.sevenDayAverage != null
                ? '7-day average ${formatMs(o.hrv!.sevenDayAverage)}'
                : null,
            missingReason: 'not recorded in this export',
          ),
          MetricTile(
            label: 'Nights recorded',
            value: formatCount(o.sleep?.recordsInWindow, 'night', 'nights'),
            emphasis: true,
            context1: 'in the last 7 days',
            missingReason: 'no night was exported in this window',
          ),
        ],
      ),
    );
  }

  Widget _history(BuildContext context, MetricSeries? series) {
    final p = context.palette;
    final days = _range == HealthRange.today ? 7 : _range.days;
    final windowed = series?.window(days);

    if (windowed == null || windowed.isEmpty) {
      return VoltraCard(
        title: 'History',
        icon: Icons.history,
        child: Text(
          'No nights in this window. Apple Health records one entry per night, '
          'so a short export contains only a few.',
          style: TextStyle(color: p.textMuted, fontSize: 13),
        ),
      );
    }

    final avg = windowed.average;
    final best = windowed.best;
    final worst = windowed.lowest;

    return VoltraCard(
      title: 'History',
      icon: Icons.history,
      trailing: Text(
        '${windowed.points.length} ${windowed.points.length == 1 ? "night" : "nights"}',
        style: TextStyle(color: p.textMuted, fontSize: 11.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avg != null)
            Text(
              'Averaging ${formatHours(avg)} a night'
              '${best != null && worst != null ? ", between ${formatHours(worst)} and ${formatHours(best)}" : ""}.',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 18),
          TrendChart(series: windowed, formatValue: (v) => formatHours(v)),
          const SizedBox(height: 20),
          Text('NIGHTS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          for (final point in windowed.points.reversed.take(7))
            FactRow(
              '${_dateLabel(point.day)}'
              '${point.sleepStart != null && point.sleepEnd != null ? "   ${formatClock(point.sleepStart)} → ${formatClock(point.sleepEnd)}" : ""}',
              formatHours(point.value),
            ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }
}
