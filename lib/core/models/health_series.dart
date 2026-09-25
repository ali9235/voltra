/// Typed models for GET /health/series?days=N — daily aggregates used by the
/// Health and Sleep charts.
///
/// The server has already collapsed thousands of raw samples into one point
/// per day. Nothing in the app ever touches the raw arrays, and nothing is
/// interpolated: a day with no sample simply has no point.
library;

import 'health_summary.dart' show parseHealthDate;

double? _num(Object? v) => v is num ? v.toDouble() : null;
int? _int(Object? v) => v is num ? v.toInt() : null;
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

enum SeriesKind { total, average, sleep }

class SeriesPoint {
  final DateTime day;
  final double? value;

  /// Only present on averaged metrics.
  final double? min;
  final double? max;
  final int samples;

  /// Only present on sleep points.
  final DateTime? sleepStart;
  final DateTime? sleepEnd;
  final bool stagesAvailable;

  const SeriesPoint({
    required this.day,
    this.value,
    this.min,
    this.max,
    this.samples = 0,
    this.sleepStart,
    this.sleepEnd,
    this.stagesAvailable = false,
  });

  static SeriesPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    final day = parseHealthDate(json['date']);
    if (day == null) return null;
    return SeriesPoint(
      day: day,
      value: _num(json['value']),
      min: _num(json['min']),
      max: _num(json['max']),
      samples: _int(json['samples']) ?? 0,
      sleepStart: parseHealthDate(json['sleep_start']),
      sleepEnd: parseHealthDate(json['sleep_end']),
      stagesAvailable: json['stages_available'] == true,
    );
  }
}

class MetricSeries {
  final String? unit;
  final SeriesKind kind;
  final List<SeriesPoint> points;

  const MetricSeries({
    this.unit,
    this.kind = SeriesKind.total,
    this.points = const <SeriesPoint>[],
  });

  static MetricSeries? fromJson(Object? json) {
    if (json is! Map) return null;

    final raw = json['points'];
    final points = raw is List
        ? raw
              .map(SeriesPoint.fromJson)
              .whereType<SeriesPoint>()
              .toList(growable: false)
        : const <SeriesPoint>[];

    if (points.isEmpty) return null;

    return MetricSeries(
      unit: _str(json['unit']),
      kind: switch (_str(json['kind'])) {
        'average' => SeriesKind.average,
        'sleep' => SeriesKind.sleep,
        _ => SeriesKind.total,
      },
      points: points,
    );
  }

  bool get isEmpty => points.isEmpty;

  List<double> get values =>
      points.map((p) => p.value).whereType<double>().toList(growable: false);

  double? get latest => points.isEmpty ? null : points.last.value;

  double? get average {
    final v = values;
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  double? get best {
    final v = values;
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a > b ? a : b);
  }

  double? get lowest {
    final v = values;
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a < b ? a : b);
  }

  /// Total across the window. Only meaningful for summed metrics.
  double? get total {
    final v = values;
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b);
  }

  /// Last point minus the average of every earlier point. The number the
  /// "higher / lower than usual" sentences are built from.
  double? get deltaVsEarlierAverage {
    if (points.length < 2) return null;
    final earlier = points
        .sublist(0, points.length - 1)
        .map((p) => p.value)
        .whereType<double>()
        .toList();
    final last = points.last.value;
    if (earlier.isEmpty || last == null) return null;
    final base = earlier.reduce((a, b) => a + b) / earlier.length;
    return last - base;
  }

  /// Only the most recent [days] points.
  MetricSeries window(int days) {
    if (points.length <= days) return this;
    return MetricSeries(
      unit: unit,
      kind: kind,
      points: points.sublist(points.length - days),
    );
  }
}

class HealthSeries {
  final DateTime? referenceDate;
  final int daysRequested;

  /// How many distinct days actually carry data. Shown verbatim so a 30-day
  /// view over a 7-day export is never mistaken for a full month.
  final int daysWithData;
  final DateTime? firstDay;
  final DateTime? lastDay;

  final MetricSeries? steps;
  final MetricSeries? activeEnergy;
  final MetricSeries? exerciseTime;
  final MetricSeries? distance;
  final MetricSeries? heartRate;
  final MetricSeries? restingHeartRate;
  final MetricSeries? hrv;
  final MetricSeries? sleep;

  const HealthSeries({
    this.referenceDate,
    this.daysRequested = 30,
    this.daysWithData = 0,
    this.firstDay,
    this.lastDay,
    this.steps,
    this.activeEnergy,
    this.exerciseTime,
    this.distance,
    this.heartRate,
    this.restingHeartRate,
    this.hrv,
    this.sleep,
  });

  factory HealthSeries.fromJson(Map<String, dynamic> json) {
    final series = json['series'];
    MetricSeries? pick(String key) =>
        series is Map ? MetricSeries.fromJson(series[key]) : null;

    return HealthSeries(
      referenceDate: parseHealthDate(json['reference_date']),
      daysRequested: _int(json['days_requested']) ?? 30,
      daysWithData: _int(json['days_with_data']) ?? 0,
      firstDay: parseHealthDate(json['first_day']),
      lastDay: parseHealthDate(json['last_day']),
      steps: pick('steps'),
      activeEnergy: pick('active_energy'),
      exerciseTime: pick('exercise_time'),
      distance: pick('walking_running_distance'),
      heartRate: pick('heart_rate'),
      restingHeartRate: pick('resting_heart_rate'),
      hrv: pick('hrv'),
      sleep: pick('sleep'),
    );
  }

  /// True when the export covers fewer days than the view asked for. The UI
  /// says so out loud instead of drawing an empty month.
  bool coversFewerDaysThan(int days) => daysWithData < days;
}
