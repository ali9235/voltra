import 'package:flutter/material.dart';

import '../../app/voltra_services.dart';
import '../../core/health_format.dart';
import '../../core/services/health_summary_service.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/health_state_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/trend_chart.dart';
import '../../core/widgets/voltra_card.dart';

/// Heart, movement and energy — aggregated, never listed.
///
/// Every panel shows one headline number, one or two lines of context and a
/// daily trend. The thousands of raw samples behind them are collapsed by the
/// server and never reach the screen.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
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

        final series = healthSummary.series;

        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Heart, movement and energy',
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
            _coverageNotice(context, series),
            if (_range == HealthRange.today)
              _today(context, summary)
            else
              _window(context, series),
            HealthStatusView.sourceFooter(context, healthSummary),
          ],
        );
      },
    );
  }

  /// Says out loud when the export holds fewer days than the selected window,
  /// so a 30-day view over a 7-day export is never read as a flat month.
  Widget _coverageNotice(BuildContext context, HealthSeries? series) {
    if (_range == HealthRange.today || series == null) {
      return const SizedBox.shrink();
    }
    if (!series.coversFewerDaysThan(_range.days)) {
      return const SizedBox.shrink();
    }

    return NoticeBox(
      icon: Icons.history_toggle_off,
      color: context.palette.textSecondary,
      text:
          'This export covers ${series.daysWithData} '
          '${series.daysWithData == 1 ? "day" : "days"}, not ${_range.days}. '
          'Everything below is the ${series.daysWithData} days VOLTRA actually '
          'has.',
    );
  }

  // ---------------------------------------------------------------- today

  Widget _today(BuildContext context, HealthSummary summary) {
    final o = summary.overview;

    return Column(
      children: [
        VoltraCard(
          title: 'Heart',
          icon: Icons.favorite_outline,
          child: MetricGrid(
            tiles: [
              MetricTile(
                label: 'Heart rate',
                value: formatBpm(o.heartRate?.latest),
                emphasis: true,
                context1: o.heartRate?.latestAt != null
                    ? 'latest reading · ${formatAge(DateTime.now().difference(o.heartRate!.latestAt!.toLocal()))}'
                    : null,
                context2: o.heartRate?.todayAverage != null
                    ? 'today average ${formatBpm(o.heartRate!.todayAverage)}'
                    : null,
                missingReason: 'no heart samples in this export',
              ),
              MetricTile(
                label: 'Today range',
                value:
                    o.heartRate?.todayMin != null &&
                        o.heartRate?.todayMax != null
                    ? '${o.heartRate!.todayMin!.round()}–${o.heartRate!.todayMax!.round()}'
                    : noData,
                emphasis: true,
                context1:
                    o.heartRate?.todaySamples != null &&
                        o.heartRate!.todaySamples > 0
                    ? 'bpm across ${o.heartRate!.todaySamples} readings'
                    : null,
                missingReason: 'no readings recorded today yet',
              ),
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
            ],
          ),
        ),
        const SizedBox(height: 18),
        VoltraCard(
          title: 'Movement',
          icon: Icons.directions_walk,
          child: MetricGrid(
            tiles: [
              MetricTile(
                label: 'Steps',
                value: formatSteps(o.steps?.todayTotal),
                emphasis: true,
                context1: o.steps?.sevenDayDailyAverage != null
                    ? 'daily average ${formatSteps(o.steps!.sevenDayDailyAverage)}'
                    : null,
                missingReason: 'no samples today yet',
              ),
              MetricTile(
                label: 'Distance',
                value: formatKm(o.walkingRunningDistance?.todayTotal),
                emphasis: true,
                context1: o.walkingRunningDistance?.sevenDayDailyAverage != null
                    ? 'daily average ${formatKm(o.walkingRunningDistance!.sevenDayDailyAverage)}'
                    : null,
                missingReason: 'no samples today yet',
              ),
              MetricTile(
                label: 'Exercise',
                value: formatMinutes(o.exerciseTime?.todayTotal),
                emphasis: true,
                context1: o.exerciseTime?.sevenDayTotal != null
                    ? '${formatMinutes(o.exerciseTime!.sevenDayTotal)} in the last 7 days'
                    : null,
                missingReason: 'no exercise minutes today yet',
              ),
              MetricTile(
                label: 'Active energy',
                value: formatKcal(o.activeEnergy?.todayKcal),
                emphasis: true,
                context1: o.activeEnergy?.sevenDayDailyAverageKcal != null
                    ? 'daily average ${formatKcal(o.activeEnergy!.sevenDayDailyAverageKcal)}'
                    : null,
                missingReason: 'no samples today yet',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- window

  Widget _window(BuildContext context, HealthSeries? series) {
    if (series == null) {
      return VoltraCard(
        child: Text(
          'VOLTRA could not load the daily history from the health server. '
          'The numbers for today above are still live.',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
        ),
      );
    }

    final days = _range.days;

    return Column(
      children: [
        _trendCard(
          context,
          title: 'Steps',
          icon: Icons.directions_walk,
          series: series.steps?.window(days),
          format: formatSteps,
          summaryLine: (s) {
            final total = s.total;
            final avg = s.average;
            if (total == null || avg == null) return null;
            return '${formatSteps(total)} steps over ${s.points.length} days — '
                'averaging ${formatSteps(avg)} a day.';
          },
          missingReason: 'No step data in this window.',
        ),
        const SizedBox(height: 18),
        _trendCard(
          context,
          title: 'Resting heart rate',
          icon: Icons.favorite_outline,
          series: series.restingHeartRate?.window(days),
          format: (v) => '${v.round()} bpm',
          summaryLine: (s) {
            final avg = s.average;
            final low = s.lowest;
            final high = s.best;
            if (avg == null || low == null || high == null) return null;
            return 'Averaging ${avg.round()} bpm, ranging '
                '${low.round()}–${high.round()} across ${s.points.length} days.';
          },
          missingReason:
              'Resting heart rate is recorded about once a day, and none '
              'landed in this window.',
        ),
        const SizedBox(height: 18),
        _trendCard(
          context,
          title: 'HRV',
          icon: Icons.graphic_eq,
          series: series.hrv?.window(days),
          format: (v) => '${v.round()} ms',
          summaryLine: (s) {
            final avg = s.average;
            final delta = s.deltaVsEarlierAverage;
            if (avg == null) return null;
            if (delta == null || delta.abs() < 3) {
              return 'Averaging ${avg.round()} ms across ${s.points.length} days.';
            }
            return 'Averaging ${avg.round()} ms. The most recent day is '
                '${delta > 0 ? "above" : "below"} that by '
                '${delta.abs().round()} ms.';
          },
          missingReason: 'No HRV readings in this window.',
        ),
        const SizedBox(height: 18),
        _trendCard(
          context,
          title: 'Active energy',
          icon: Icons.local_fire_department_outlined,
          series: series.activeEnergy?.window(days),
          format: (v) => '${v.round()} kcal',
          summaryLine: (s) {
            final total = s.total;
            final avg = s.average;
            if (total == null || avg == null) return null;
            return '${total.round()} kcal burned over ${s.points.length} days — '
                'averaging ${avg.round()} kcal a day.';
          },
          missingReason: 'No active energy data in this window.',
        ),
        const SizedBox(height: 18),
        _trendCard(
          context,
          title: 'Exercise minutes',
          icon: Icons.fitness_center_outlined,
          series: series.exerciseTime?.window(days),
          format: (v) => '${v.round()} min',
          summaryLine: (s) {
            final total = s.total;
            final active = s.points.where((p) => (p.value ?? 0) > 0).length;
            if (total == null) return null;
            return '${formatMinutes(total)} across $active '
                '${active == 1 ? "day" : "days"} with recorded exercise.';
          },
          missingReason: 'No exercise minutes in this window.',
        ),
      ],
    );
  }

  Widget _trendCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required MetricSeries? series,
    required String Function(double) format,
    required String? Function(MetricSeries) summaryLine,
    required String missingReason,
  }) {
    final p = context.palette;

    if (series == null || series.isEmpty) {
      return VoltraCard(
        title: title,
        icon: icon,
        child: Text(
          missingReason,
          style: TextStyle(color: p.textMuted, fontSize: 13),
        ),
      );
    }

    final line = summaryLine(series);

    return VoltraCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line != null) ...[
            Text(
              line,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
          ],
          TrendChart(series: series, formatValue: format),
        ],
      ),
    );
  }
}
