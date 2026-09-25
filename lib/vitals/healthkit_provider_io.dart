import 'dart:io' show Platform;

import 'package:health/health.dart';

import 'vitals_provider.dart';

/// True only on a real iOS build.
bool get platformSupportsHealthKit => Platform.isIOS;

/// Returns the HealthKit provider on iOS, otherwise null so the caller falls
/// back to the Mock/Demo provider. On Android this returns null on purpose:
/// VOLTRA targets Apple Health, and Health Connect is a separate project.
VitalsProvider? createPlatformHealthProvider() {
  if (!Platform.isIOS) return null;
  return HealthKitVitalsProvider();
}

/// Real Apple HealthKit integration, built on the `health` plugin (13.3.x).
///
/// VERIFICATION STATUS: this code has never been compiled by Xcode nor run on
/// an iPhone, because no macOS toolchain or iOS device was available. It is a
/// complete implementation, not a placeholder, but it must be treated as
/// unverified until it has actually run on device.
///
/// Only READ access is requested, and only for the seven types VOLTRA
/// actually displays. Nothing is ever written back to Health.
class HealthKitVitalsProvider implements VitalsProvider {
  HealthKitVitalsProvider({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  /// The complete set of types VOLTRA reads. Keep this list minimal —
  /// requesting more than the app displays is both a privacy problem and a
  /// common App Review rejection.
  static const List<HealthDataType> readTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
  ];

  static final List<HealthDataAccess> _readOnly = List<HealthDataAccess>.filled(
    readTypes.length,
    HealthDataAccess.READ,
  );

  @override
  String get displayName => 'Apple Health (HealthKit)';

  @override
  bool get providesRealData => true;

  @override
  String get statusDescription =>
      'Reads steps, sleep, heart rate, resting heart rate, workouts, active '
      'energy and walking/running distance from Apple Health. Read-only.';

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<VitalsAccess> checkAccess() async {
    if (!Platform.isIOS) return VitalsAccess.unsupported;
    await _ensureConfigured();

    // NOTE: on iOS, HealthKit deliberately never reveals whether READ access
    // was granted — Apple treats that as leaking health information. So
    // hasPermissions() returns null here and the only honest answer is
    // "not determined". Actual availability is discovered by reading.
    final has = await _health.hasPermissions(readTypes, permissions: _readOnly);
    if (has == true) return VitalsAccess.granted;
    if (has == false) return VitalsAccess.denied;
    return VitalsAccess.notDetermined;
  }

  @override
  Future<VitalsAccess> requestAccess() async {
    if (!Platform.isIOS) return VitalsAccess.unsupported;
    await _ensureConfigured();

    final granted = await _health.requestAuthorization(
      readTypes,
      permissions: _readOnly,
    );
    return granted ? VitalsAccess.granted : VitalsAccess.denied;
  }

  @override
  Future<VitalsSnapshot> read() async {
    if (!Platform.isIOS) {
      throw const VitalsAccessException('HealthKit is only available on iOS.');
    }
    await _ensureConfigured();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    // Sleep is reported against "last night": yesterday 18:00 until now.
    final sleepWindowStart = startOfDay.subtract(
      const Duration(hours: 6),
    ); // 18:00 yesterday
    final weekAgo = now.subtract(const Duration(days: 7));
    final dayAgo = now.subtract(const Duration(days: 1));

    try {
      final steps = await _readSteps(startOfDay, now);
      final sleepHours = await _readSleepHours(sleepWindowStart, now);
      final restingHr = await _latestNumeric(
        HealthDataType.RESTING_HEART_RATE,
        weekAgo,
        now,
      );
      final heartRate = await _latestNumeric(
        HealthDataType.HEART_RATE,
        dayAgo,
        now,
      );
      final activeEnergy = await _sumNumeric(
        HealthDataType.ACTIVE_ENERGY_BURNED,
        startOfDay,
        now,
      );
      final distance = await _sumNumeric(
        HealthDataType.DISTANCE_WALKING_RUNNING,
        startOfDay,
        now,
      );
      final workoutMinutes = await _readWorkoutMinutes(startOfDay, now);

      return VitalsSnapshot(
        source: VitalsSource.healthKit,
        takenAt: now,
        steps: steps,
        sleepHours: sleepHours,
        restingHeartRate: restingHr,
        heartRate: heartRate,
        workoutMinutes: workoutMinutes,
        activeEnergyKcal: activeEnergy,
        distanceMeters: distance,
      );
    } on HealthException catch (e) {
      throw VitalsAccessException('Apple Health refused the request: $e');
    }
  }

  // --------------------------------------------------------------- readers
  //
  // Every reader returns null rather than 0 when Health has nothing, so the
  // UI can say "NO DATA" instead of showing a number the user never earned.

  Future<int?> _readSteps(DateTime start, DateTime end) async {
    // getTotalStepsInInterval is HealthKit's own de-duplicated sum, which is
    // more accurate than adding raw samples from several sources.
    final total = await _health.getTotalStepsInInterval(start, end);
    if (total != null) return total;

    final points = await _points(HealthDataType.STEPS, start, end);
    if (points.isEmpty) return null;
    return _sumOf(points).round();
  }

  Future<double?> _readSleepHours(DateTime start, DateTime end) async {
    final points = await _points(HealthDataType.SLEEP_ASLEEP, start, end);
    if (points.isEmpty) return null;

    var minutes = 0.0;
    for (final p in points) {
      minutes += p.dateTo.difference(p.dateFrom).inMinutes.toDouble();
    }
    if (minutes <= 0) return null;
    return minutes / 60.0;
  }

  Future<int?> _readWorkoutMinutes(DateTime start, DateTime end) async {
    final points = await _points(HealthDataType.WORKOUT, start, end);
    if (points.isEmpty) return null;

    var minutes = 0;
    for (final p in points) {
      minutes += p.dateTo.difference(p.dateFrom).inMinutes;
    }
    return minutes;
  }

  Future<double?> _latestNumeric(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    final points = await _points(type, start, end);
    if (points.isEmpty) return null;

    points.sort((a, b) => a.dateTo.compareTo(b.dateTo));
    final value = points.last.value;
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    return null;
  }

  Future<double?> _sumNumeric(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    final points = await _points(type, start, end);
    if (points.isEmpty) return null;
    return _sumOf(points);
  }

  double _sumOf(List<HealthDataPoint> points) {
    var total = 0.0;
    for (final p in points) {
      final v = p.value;
      if (v is NumericHealthValue) total += v.numericValue.toDouble();
    }
    return total;
  }

  /// One guarded query. A failure on a single metric must not blank out the
  /// whole screen, so it degrades to "no data" for that metric only.
  Future<List<HealthDataPoint>> _points(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _health.getHealthDataFromTypes(
        types: <HealthDataType>[type],
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      return const <HealthDataPoint>[];
    }
  }
}
