/// Typed models for the payload returned by GET /health/summary.
///
/// Source chain:
///   Apple Watch -> Apple Health (iPhone) -> Health Auto Export
///   -> POST /health on the local Flask server -> health_payload.json
///   -> GET /health/summary -> these models.
///
/// Rules:
///   * Every metric is nullable. A missing metric is NULL, never 0, never a
///     guessed value. The UI renders null as "NO DATA".
///   * Sleep stages are only trustworthy when [SleepSummary.stagesAvailable]
///     is true. The current export writes zeros for awake/core/deep/rem, so
///     the UI MUST gate on that flag instead of showing four zero bars.
library;

double? _num(Object? v) => v is num ? v.toDouble() : null;

int? _int(Object? v) => v is num ? v.toInt() : null;

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

/// Parses the two date shapes the server emits:
///   ISO-8601          "2026-09-22T00:31:17+03:00"   (latest_at, ...)
///   Health Auto Export "2026-09-20 03:11:01 +0300"  (sleepStart/sleepEnd)
DateTime? parseHealthDate(Object? value) {
  final raw = _str(value);
  if (raw == null) return null;

  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso;

  // "YYYY-MM-DD HH:MM:SS +0300" -> "YYYY-MM-DDTHH:MM:SS+03:00"
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})\s*([+-])(\d{2}):?(\d{2})$',
  ).firstMatch(raw.trim());

  if (match == null) return null;

  return DateTime.tryParse(
    '${match.group(1)}T${match.group(2)}'
    '${match.group(3)}${match.group(4)}:${match.group(5)}',
  );
}

/// A metric the server averages rather than sums: heart rate, resting heart
/// rate, HRV.
class PointMetric {
  final String? unit;
  final double? latest;
  final DateTime? latestAt;
  final double? todayAverage;
  final double? sevenDayAverage;
  final int todaySamples;
  final int sevenDaySamples;
  final double? todayMin;
  final double? todayMax;
  final double? latestMin;
  final double? latestMax;

  const PointMetric({
    this.unit,
    this.latest,
    this.latestAt,
    this.todayAverage,
    this.sevenDayAverage,
    this.todaySamples = 0,
    this.sevenDaySamples = 0,
    this.todayMin,
    this.todayMax,
    this.latestMin,
    this.latestMax,
  });

  static PointMetric? fromJson(Object? json) {
    if (json is! Map) return null;
    return PointMetric(
      unit: _str(json['unit']),
      latest: _num(json['latest']),
      latestAt: parseHealthDate(json['latest_at']),
      todayAverage: _num(json['today_average']),
      sevenDayAverage: _num(json['seven_day_average']),
      todaySamples: _int(json['today_samples']) ?? 0,
      sevenDaySamples: _int(json['seven_day_samples']) ?? 0,
      todayMin: _num(json['today_min']),
      todayMax: _num(json['today_max']),
      latestMin: _num(json['latest_min']),
      latestMax: _num(json['latest_max']),
    );
  }

  bool get hasValue => latest != null;
}

/// A metric the server sums per day: steps, active energy, exercise minutes,
/// walking + running distance.
class TotalMetric {
  final String? unit;
  final double? latestSample;
  final DateTime? latestAt;
  final double? todayTotal;
  final double? sevenDayTotal;
  final double? sevenDayDailyAverage;
  final int daysWithData;

  /// Only populated for active_energy, which the export reports in kJ.
  final double? todayKcal;
  final double? sevenDayDailyAverageKcal;

  const TotalMetric({
    this.unit,
    this.latestSample,
    this.latestAt,
    this.todayTotal,
    this.sevenDayTotal,
    this.sevenDayDailyAverage,
    this.daysWithData = 0,
    this.todayKcal,
    this.sevenDayDailyAverageKcal,
  });

  static TotalMetric? fromJson(Object? json) {
    if (json is! Map) return null;
    return TotalMetric(
      unit: _str(json['unit']),
      latestSample: _num(json['latest_sample']),
      latestAt: parseHealthDate(json['latest_at']),
      todayTotal: _num(json['today_total']),
      sevenDayTotal: _num(json['seven_day_total']),
      sevenDayDailyAverage: _num(json['seven_day_daily_average']),
      daysWithData: _int(json['days_with_data']) ?? 0,
      todayKcal: _num(json['today_kcal']),
      sevenDayDailyAverageKcal: _num(json['seven_day_daily_average_kcal']),
    );
  }

  /// True when the export has not yet delivered any sample dated today.
  /// Common in the morning — it is NOT an error and must not be shown as 0.
  bool get todayMissing => todayTotal == null;
}

class SleepStages {
  final double? awake;
  final double? core;
  final double? deep;
  final double? rem;

  const SleepStages({this.awake, this.core, this.deep, this.rem});

  static SleepStages fromJson(Object? json) {
    if (json is! Map) return const SleepStages();
    return SleepStages(
      awake: _num(json['awake']),
      core: _num(json['core']),
      deep: _num(json['deep']),
      rem: _num(json['rem']),
    );
  }
}

class SleepSummary {
  final String? unit;
  final DateTime? latestDate;
  final DateTime? sleepStart;
  final DateTime? sleepEnd;
  final double? totalSleepHours;
  final double? asleepHours;
  final SleepStages stages;

  /// Server-computed. False while the export reports all stages as zero.
  final bool stagesAvailable;
  final double? sevenDayAverageSleepHours;
  final int recordsInWindow;
  final String? source;

  const SleepSummary({
    this.unit,
    this.latestDate,
    this.sleepStart,
    this.sleepEnd,
    this.totalSleepHours,
    this.asleepHours,
    this.stages = const SleepStages(),
    this.stagesAvailable = false,
    this.sevenDayAverageSleepHours,
    this.recordsInWindow = 0,
    this.source,
  });

  static SleepSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    return SleepSummary(
      unit: _str(json['unit']),
      latestDate: parseHealthDate(json['latest_date']),
      sleepStart: parseHealthDate(json['sleep_start']),
      sleepEnd: parseHealthDate(json['sleep_end']),
      totalSleepHours: _num(json['total_sleep_hours']),
      asleepHours: _num(json['asleep_hours']),
      stages: SleepStages.fromJson(json['stages']),
      stagesAvailable: json['stages_available'] == true,
      sevenDayAverageSleepHours: _num(json['seven_day_average_sleep_hours']),
      recordsInWindow: _int(json['sleep_records_in_window']) ?? 0,
      source: _str(json['source']),
    );
  }

  /// Difference between the latest night and the 7-day average, in hours.
  /// Null unless both numbers are real.
  double? get deltaVsWeeklyAverage {
    final total = totalSleepHours;
    final avg = sevenDayAverageSleepHours;
    if (total == null || avg == null) return null;
    return total - avg;
  }
}

class HealthOverview {
  final PointMetric? heartRate;
  final PointMetric? restingHeartRate;
  final PointMetric? hrv;
  final TotalMetric? steps;
  final TotalMetric? activeEnergy;
  final TotalMetric? exerciseTime;
  final TotalMetric? walkingRunningDistance;
  final SleepSummary? sleep;

  const HealthOverview({
    this.heartRate,
    this.restingHeartRate,
    this.hrv,
    this.steps,
    this.activeEnergy,
    this.exerciseTime,
    this.walkingRunningDistance,
    this.sleep,
  });

  static HealthOverview fromJson(Object? json) {
    if (json is! Map) return const HealthOverview();
    return HealthOverview(
      heartRate: PointMetric.fromJson(json['heart_rate']),
      restingHeartRate: PointMetric.fromJson(json['resting_heart_rate']),
      hrv: PointMetric.fromJson(json['hrv']),
      steps: TotalMetric.fromJson(json['steps']),
      activeEnergy: TotalMetric.fromJson(json['active_energy']),
      exerciseTime: TotalMetric.fromJson(json['exercise_time']),
      walkingRunningDistance: TotalMetric.fromJson(
        json['walking_running_distance'],
      ),
      sleep: SleepSummary.fromJson(json['sleep']),
    );
  }

  /// Metrics the server returned nothing for. Used to explain partial data
  /// instead of silently rendering blanks.
  List<String> get missingMetrics {
    return <String>[
      if (heartRate == null) 'heart rate',
      if (restingHeartRate == null) 'resting heart rate',
      if (hrv == null) 'HRV',
      if (steps == null) 'steps',
      if (activeEnergy == null) 'active energy',
      if (exerciseTime == null) 'exercise time',
      if (walkingRunningDistance == null) 'distance',
      if (sleep == null) 'sleep',
    ];
  }
}

/// The whole /health/summary response.
class HealthSummary {
  /// The day the server used as "today" — derived from the newest sample in
  /// the payload, NOT from the PC clock.
  final DateTime? referenceDate;

  /// Timestamp of the newest sample of any metric in the payload. This is the
  /// number that tells us whether the export is stale.
  final DateTime? latestSampleAt;
  final List<String> availableMetrics;
  final HealthOverview overview;

  /// When this app fetched the summary.
  final DateTime fetchedAt;

  const HealthSummary({
    this.referenceDate,
    this.latestSampleAt,
    this.availableMetrics = const <String>[],
    this.overview = const HealthOverview(),
    required this.fetchedAt,
  });

  factory HealthSummary.fromJson(Map<String, dynamic> json) {
    final metrics = json['available_metrics'];
    return HealthSummary(
      referenceDate: parseHealthDate(json['reference_date']),
      latestSampleAt: parseHealthDate(json['latest_sample_at']),
      availableMetrics: metrics is List
          ? metrics.whereType<String>().toList(growable: false)
          : const <String>[],
      overview: HealthOverview.fromJson(json['overview']),
      fetchedAt: DateTime.now(),
    );
  }

  /// How old the newest Apple Watch sample is.
  Duration? get dataAge {
    final at = latestSampleAt;
    if (at == null) return null;
    return DateTime.now().difference(at.toLocal());
  }

  /// Anything older than this means Health Auto Export has not run recently.
  static const Duration staleAfter = Duration(hours: 6);

  bool get isStale {
    final age = dataAge;
    return age != null && age > staleAfter;
  }

  /// True when the server answered but had nothing usable in it.
  bool get isEmpty =>
      overview.missingMetrics.length == 8 || availableMetrics.isEmpty;

  bool get isPartial => !isEmpty && overview.missingMetrics.isNotEmpty;
}
