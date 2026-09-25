import '../../core/context_engine/context_state.dart';
import '../../core/health_format.dart';
import '../../core/models/health_series.dart';
import '../../core/models/health_summary.dart';
import '../../core/services/health_summary_service.dart' show HealthStatus;
import '../insights/insight_builder.dart';

/// Answers questions from the data VOLTRA actually holds.
///
/// Rule-based on purpose: no cloud model is wired up, and nothing is
/// generated that is not backed by a number in the export. When the answer
/// would require data VOLTRA does not have, it says which data is missing.
class LocalAnswers {
  const LocalAnswers._();

  static String answer(
    String question, {
    required HealthSummary? summary,
    required HealthSeries? series,
    required HealthStatus status,
    required ContextSnapshot context,
  }) {
    final q = question.toLowerCase();

    if (summary == null) {
      return switch (status) {
        HealthStatus.serverOffline =>
          'I cannot reach the health server on port 8766, so I have no data '
              'to answer from. Start VOLTRA with !VOLTRA.bat and ask again.',
        HealthStatus.noData =>
          'The health server is running but nothing has been exported yet. '
              'Run an export from Health Auto Export on your iPhone.',
        _ =>
          'I do not have your health summary yet. Try the refresh button '
              'at the top right.',
      };
    }

    final o = summary.overview;

    if (_matches(q, ['sleep', 'slept', 'rest last night', 'bed'])) {
      return _sleepAnswer(q, o.sleep, series?.sleep);
    }

    if (_matches(q, ['train', 'workout', 'exercise', 'gym', 'hard today'])) {
      return _trainingAnswer(o, context);
    }

    if (_matches(q, ['resting heart', 'resting hr', 'rhr'])) {
      return _restingAnswer(o.restingHeartRate);
    }

    if (_matches(q, ['hrv', 'variability'])) {
      return _hrvAnswer(o.hrv);
    }

    if (_matches(q, ['heart rate', 'bpm', 'pulse'])) {
      return _heartAnswer(o.heartRate);
    }

    if (_matches(q, [
      'step',
      'active',
      'move',
      'walk',
      'distance',
      'calorie',
      'energy',
    ])) {
      return _activityAnswer(o);
    }

    if (_matches(q, ['summary', 'how am i', 'overview', 'today'])) {
      return _overallAnswer(summary, series);
    }

    return 'I answer from your exported Apple Watch data — sleep, heart rate, '
        'resting heart rate, HRV, steps, active energy, exercise minutes and '
        'distance. Ask me about any of those, or try "how did I sleep this '
        'week?".';
  }

  static bool _matches(String q, List<String> keys) =>
      keys.any((k) => q.contains(k));

  static String _sleepAnswer(
    String q,
    SleepSummary? sleep,
    MetricSeries? series,
  ) {
    if (sleep == null) {
      return 'There is no sleep record in the current export. Apple Health '
          'writes a night only once the Apple Watch has finished processing '
          'it, so the most recent night can take a while to appear.';
    }

    final wantsWeek = q.contains('week') || q.contains('7');

    if (wantsWeek) {
      if (series == null || series.points.isEmpty) {
        return 'I only have the single most recent night '
            '(${formatHours(sleep.totalSleepHours)}), not a week of history.';
      }
      final avg = series.average;
      final low = series.lowest;
      final high = series.best;
      final nights = series.points.length;
      return 'Over the last $nights ${nights == 1 ? "night" : "nights"} you '
          'averaged ${formatHours(avg)}, between ${formatHours(low)} and '
          '${formatHours(high)}. Your most recent night was '
          '${formatHours(sleep.totalSleepHours)}.';
    }

    final delta = formatSleepDelta(sleep.deltaVsWeeklyAverage);
    final window = sleep.sleepStart != null && sleep.sleepEnd != null
        ? ' from ${formatClock(sleep.sleepStart)} to '
              '${formatClock(sleep.sleepEnd)}'
        : '';

    return 'Your last recorded night was ${formatHours(sleep.totalSleepHours)}'
        '$window'
        '${delta != null ? " — $delta" : ""}.'
        '${sleep.stagesAvailable ? "" : " Sleep stages are not in this export, so I cannot break it into deep and REM."}';
  }

  static String _trainingAnswer(HealthOverview o, ContextSnapshot context) {
    final parts = <String>[];

    final sleep = o.sleep?.totalSleepHours;
    final sleepAvg = o.sleep?.sevenDayAverageSleepHours;
    final rhr = o.restingHeartRate?.latest;
    final rhrAvg = o.restingHeartRate?.sevenDayAverage;
    final hrv = o.hrv?.latest;
    final hrvAvg = o.hrv?.sevenDayAverage;

    if (sleep == null && rhr == null && hrv == null) {
      return 'I do not have sleep, resting heart rate or HRV in this export, '
          'so I have nothing to base an answer on.';
    }

    if (sleep != null) {
      parts.add(
        sleepAvg != null
            ? 'You slept ${formatHours(sleep)} against a 7-day average of '
                  '${formatHours(sleepAvg)}'
            : 'You slept ${formatHours(sleep)}',
      );
    }
    if (rhr != null) {
      parts.add(
        rhrAvg != null
            ? 'resting heart rate ${rhr.round()} bpm against a baseline of '
                  '${rhrAvg.round()}'
            : 'resting heart rate ${rhr.round()} bpm',
      );
    }
    if (hrv != null) {
      parts.add(
        hrvAvg != null
            ? 'HRV ${hrv.round()} ms against ${hrvAvg.round()} ms'
            : 'HRV ${hrv.round()} ms',
      );
    }

    final flags = <String>[];
    if (sleep != null && sleepAvg != null && (sleep - sleepAvg) * 60 <= -45) {
      flags.add('sleep is well down on your usual');
    }
    if (rhr != null && rhrAvg != null && rhr - rhrAvg >= 4) {
      flags.add('resting heart rate is elevated');
    }
    if (hrv != null && hrvAvg != null && hrv - hrvAvg <= -8) {
      flags.add('HRV is below your average');
    }

    final verdict = flags.isEmpty
        ? 'Nothing in that stands out from your usual range.'
        : 'Two things worth noting: ${flags.join(" and ")}.';

    return '${parts.join(", ")}. $verdict '
        'I can report what your data shows, but the call on how hard to train '
        'is yours.';
  }

  static String _restingAnswer(PointMetric? metric) {
    final latest = metric?.latest;
    if (latest == null) {
      return 'Resting heart rate is not present in this export. Apple Health '
          'records it roughly once a day.';
    }
    final avg = metric?.sevenDayAverage;
    if (avg == null) {
      return 'Your latest resting heart rate is ${latest.round()} bpm. I do '
          'not have enough days yet for a baseline.';
    }
    final delta = latest - avg;
    final direction = delta.abs() < 2
        ? 'sitting on'
        : delta > 0
        ? '${delta.round()} bpm above'
        : '${delta.abs().round()} bpm below';
    return 'Your latest resting heart rate is ${latest.round()} bpm, '
        '$direction your 7-day average of ${avg.round()} bpm.';
  }

  static String _hrvAnswer(PointMetric? metric) {
    final latest = metric?.latest;
    if (latest == null) {
      return 'HRV is not present in this export.';
    }
    final avg = metric?.sevenDayAverage;
    return avg == null
        ? 'Your latest HRV reading is ${latest.round()} ms.'
        : 'Your latest HRV reading is ${latest.round()} ms, against a 7-day '
              'average of ${avg.round()} ms.';
  }

  static String _heartAnswer(PointMetric? metric) {
    final latest = metric?.latest;
    if (latest == null) return 'No heart rate samples are in this export.';

    final min = metric?.todayMin;
    final max = metric?.todayMax;
    final samples = metric?.todaySamples ?? 0;

    if (min == null || max == null || samples == 0) {
      return 'Your latest heart rate is ${latest.round()} bpm. No readings '
          'have arrived for today yet.';
    }
    return 'Your latest heart rate is ${latest.round()} bpm. Today it has '
        'ranged ${min.round()}–${max.round()} bpm across $samples readings.';
  }

  static String _activityAnswer(HealthOverview o) {
    final lines = <String>[];

    final steps = o.steps;
    if (steps?.todayTotal != null) {
      lines.add(
        '${formatSteps(steps!.todayTotal)} steps today'
        '${steps.sevenDayDailyAverage != null ? " against a daily average of ${formatSteps(steps.sevenDayDailyAverage)}" : ""}',
      );
    } else if (steps != null) {
      lines.add(
        'no step samples have arrived for today yet'
        '${steps.sevenDayDailyAverage != null ? ", though you average ${formatSteps(steps.sevenDayDailyAverage)} a day" : ""}',
      );
    }

    final energy = o.activeEnergy;
    if (energy?.todayKcal != null) {
      lines.add('${formatKcal(energy!.todayKcal)} of active energy');
    }

    final distance = o.walkingRunningDistance;
    if (distance?.todayTotal != null) {
      lines.add('${formatKm(distance!.todayTotal)} covered');
    }

    final exercise = o.exerciseTime;
    if (exercise?.todayTotal != null) {
      lines.add('${formatMinutes(exercise!.todayTotal)} of exercise');
    }

    if (lines.isEmpty) {
      return 'No activity data has arrived for today yet.';
    }

    return '${lines.join(", ")}.';
  }

  static String _overallAnswer(HealthSummary summary, HealthSeries? series) {
    final insights = InsightBuilder.build(summary: summary, series: series);
    if (insights.isEmpty) {
      return 'I have your latest numbers but not enough history yet to say '
          'what is unusual.';
    }
    return insights.take(3).map((i) => i.text).join(' ');
  }
}
