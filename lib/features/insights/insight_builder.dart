import '../../core/health_format.dart';
import '../../core/models/health_series.dart';
import '../../core/models/health_summary.dart';

/// How an observation should be read.
enum InsightTone { neutral, good, watch }

/// One readable sentence grounded in a real number.
class Insight {
  final String text;
  final InsightTone tone;

  /// The module this observation came from, used as a small caption.
  final String source;

  const Insight(
    this.text, {
    this.tone = InsightTone.neutral,
    required this.source,
  });
}

/// Turns the summary and the daily series into sentences.
///
/// Rules baked in here:
///   * Nothing is emitted unless the numbers behind it exist.
///   * Nothing is diagnosed. These are observations about his own data
///     compared with his own baseline — never medical claims.
///   * Comparisons need a baseline of at least two other days, otherwise the
///     observation is skipped rather than made up.
class InsightBuilder {
  const InsightBuilder._();

  static List<Insight> build({HealthSummary? summary, HealthSeries? series}) {
    final out = <Insight>[];
    final overview = summary?.overview;
    if (overview == null) return out;

    _sleep(out, overview.sleep);
    _restingHeartRate(out, overview.restingHeartRate, series?.restingHeartRate);
    _hrv(out, overview.hrv, series?.hrv);
    _activity(out, overview.steps, series?.steps);
    _training(out, overview.exerciseTime, series?.exerciseTime);

    return out;
  }

  static void _sleep(List<Insight> out, SleepSummary? sleep) {
    if (sleep == null) return;

    final total = sleep.totalSleepHours;
    final avg = sleep.sevenDayAverageSleepHours;
    if (total == null) return;

    if (avg == null) {
      out.add(
        Insight(
          'Your last recorded night was ${formatHours(total)}. '
          'VOLTRA needs a few more nights before it can compare.',
          source: 'Sleep',
        ),
      );
      return;
    }

    final deltaMinutes = ((total - avg) * 60).round();
    final absText = _minutesText(deltaMinutes.abs());

    if (deltaMinutes.abs() < 20) {
      out.add(
        Insight(
          'You slept ${formatHours(total)}, in line with your 7-day average of '
          '${formatHours(avg)}.',
          tone: InsightTone.good,
          source: 'Sleep',
        ),
      );
    } else if (deltaMinutes < 0) {
      out.add(
        Insight(
          'You slept ${formatHours(total)} — $absText less than your 7-day '
          'average of ${formatHours(avg)}.',
          tone: InsightTone.watch,
          source: 'Sleep',
        ),
      );
    } else {
      out.add(
        Insight(
          'You slept ${formatHours(total)} — $absText more than your 7-day '
          'average of ${formatHours(avg)}.',
          tone: InsightTone.good,
          source: 'Sleep',
        ),
      );
    }

    if (!sleep.stagesAvailable) {
      out.add(
        const Insight(
          'Sleep stages are not included in this export, so VOLTRA cannot say '
          'anything about deep or REM sleep.',
          source: 'Sleep',
        ),
      );
    }
  }

  static void _restingHeartRate(
    List<Insight> out,
    PointMetric? metric,
    MetricSeries? series,
  ) {
    final latest = metric?.latest;
    final baseline = metric?.sevenDayAverage;
    if (latest == null || baseline == null) return;
    if ((series?.points.length ?? 0) < 3) return;

    final delta = latest - baseline;

    if (delta.abs() < 2) {
      out.add(
        Insight(
          'Resting heart rate ${latest.round()} bpm, sitting on your baseline of '
          '${baseline.round()}.',
          tone: InsightTone.good,
          source: 'Health',
        ),
      );
    } else if (delta > 0) {
      out.add(
        Insight(
          'Resting heart rate ${latest.round()} bpm — ${delta.round()} above '
          'your 7-day baseline of ${baseline.round()}. Often follows a short '
          'night or a hard session.',
          tone: InsightTone.watch,
          source: 'Health',
        ),
      );
    } else {
      out.add(
        Insight(
          'Resting heart rate ${latest.round()} bpm — ${delta.abs().round()} '
          'below your 7-day baseline of ${baseline.round()}.',
          tone: InsightTone.good,
          source: 'Health',
        ),
      );
    }
  }

  static void _hrv(
    List<Insight> out,
    PointMetric? metric,
    MetricSeries? series,
  ) {
    final latest = metric?.latest;
    final baseline = metric?.sevenDayAverage;
    if (latest == null || baseline == null) return;
    if ((series?.points.length ?? 0) < 3) return;

    final delta = latest - baseline;
    if (delta.abs() < 5) return;

    out.add(
      Insight(
        delta > 0
            ? 'HRV ${latest.round()} ms, above your 7-day average of '
                  '${baseline.round()} ms.'
            : 'HRV ${latest.round()} ms, below your 7-day average of '
                  '${baseline.round()} ms.',
        tone: delta > 0 ? InsightTone.good : InsightTone.watch,
        source: 'Health',
      ),
    );
  }

  static void _activity(
    List<Insight> out,
    TotalMetric? metric,
    MetricSeries? series,
  ) {
    if (metric == null) return;

    final today = metric.todayTotal;
    final average = metric.sevenDayDailyAverage;

    if (today == null) {
      out.add(
        const Insight(
          'No step samples have arrived for today yet, so VOLTRA is not showing '
          'an activity total.',
          source: 'Health',
        ),
      );
      return;
    }

    if (average == null || (series?.points.length ?? 0) < 3) return;

    final ratio = today / average;
    if (ratio >= 1.15) {
      out.add(
        Insight(
          'Steps ${formatSteps(today)} today — above your daily average of '
          '${formatSteps(average)}.',
          tone: InsightTone.good,
          source: 'Health',
        ),
      );
    } else if (ratio <= 0.6) {
      out.add(
        Insight(
          'Steps ${formatSteps(today)} today — well under your daily average of '
          '${formatSteps(average)}.',
          tone: InsightTone.watch,
          source: 'Health',
        ),
      );
    }
  }

  static void _training(
    List<Insight> out,
    TotalMetric? metric,
    MetricSeries? series,
  ) {
    if (metric == null || series == null) return;

    final weekTotal = metric.sevenDayTotal;
    if (weekTotal == null) return;

    final days = series.points.where((p) => (p.value ?? 0) > 0).length;
    if (days == 0) {
      out.add(
        const Insight(
          'No exercise minutes recorded in this export window.',
          source: 'Training',
        ),
      );
      return;
    }

    out.add(
      Insight(
        '${formatMinutes(weekTotal)} of exercise across $days '
        '${days == 1 ? "day" : "days"} in the last week.',
        source: 'Training',
      ),
    );
  }

  static String _minutesText(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${minutes}m';
  }
}
