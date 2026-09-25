/// VOLTRA // VITALS — provider architecture.
///
/// Chain:
///   Apple Watch -> Apple Health (HealthKit) -> VOLTRA Companion (iPhone)
///   -> encrypted VOLTRA MESH -> VOLTRA Desktop
///
/// Rules that must never be broken:
///   * On iOS the app shows HealthKit data or nothing. Never demo values.
///   * On Web/Windows the app shows demo values, always labelled DEMO.
///   * A metric with no data is reported as null and rendered as "NO DATA".
library;

/// Where a reading came from.
enum VitalsSource {
  /// Synthetic. Must be labelled DEMO in the UI.
  demo,

  /// Read from Apple HealthKit on a real iPhone.
  healthKit,
}

extension VitalsSourceLabel on VitalsSource {
  String get label => switch (this) {
    VitalsSource.demo => 'DEMO',
    VitalsSource.healthKit => 'APPLE HEALTH',
  };

  bool get isReal => this == VitalsSource.healthKit;
}

/// Authorization state of the underlying health store.
enum VitalsAccess {
  /// The user has been through the permission sheet and reads are allowed.
  granted,

  /// The user refused, or the platform refuses to hand over data.
  denied,

  /// The permission sheet has not been shown yet.
  notDetermined,

  /// This platform has no health store at all (Web, Windows).
  unsupported,
}

/// One immutable snapshot of the metrics VOLTRA tracks.
///
/// Every metric is nullable on purpose: HealthKit legitimately returns nothing
/// for a metric the user does not record, and inventing a number there would
/// be a lie.
class VitalsSnapshot {
  final VitalsSource source;
  final DateTime takenAt;

  final int? steps;
  final double? sleepHours;
  final double? restingHeartRate;
  final double? heartRate;
  final int? workoutMinutes;
  final double? activeEnergyKcal;
  final double? distanceMeters;

  /// Daily step goal used to derive [activityPercent]. Stated explicitly so
  /// the number shown is never a mystery.
  static const int stepGoal = 10000;

  const VitalsSnapshot({
    required this.source,
    required this.takenAt,
    this.steps,
    this.sleepHours,
    this.restingHeartRate,
    this.heartRate,
    this.workoutMinutes,
    this.activeEnergyKcal,
    this.distanceMeters,
  });

  /// Progress toward [stepGoal], or null when step data is missing.
  int? get activityPercent {
    final s = steps;
    if (s == null) return null;
    return ((s / stepGoal) * 100).clamp(0, 100).round();
  }

  bool get isDemo => source == VitalsSource.demo;

  /// True when the health store gave us nothing at all.
  bool get isEmpty =>
      steps == null &&
      sleepHours == null &&
      restingHeartRate == null &&
      heartRate == null &&
      workoutMinutes == null &&
      activeEnergyKcal == null &&
      distanceMeters == null;

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'takenAt': takenAt.toIso8601String(),
    'steps': steps,
    'sleepHours': sleepHours,
    'restingHeartRate': restingHeartRate,
    'heartRate': heartRate,
    'workoutMinutes': workoutMinutes,
    'activeEnergyKcal': activeEnergyKcal,
    'distanceMeters': distanceMeters,
  };
}

/// Contract every vitals source must satisfy.
abstract class VitalsProvider {
  /// Human readable name of the backing source.
  String get displayName;

  /// True only when the data is genuine biometric data from a real device.
  bool get providesRealData;

  /// Short, truthful explanation shown in the UI.
  String get statusDescription;

  /// Current authorization state, without prompting.
  Future<VitalsAccess> checkAccess();

  /// Show the platform permission sheet if needed.
  Future<VitalsAccess> requestAccess();

  /// Read the latest snapshot. Throws [VitalsAccessException] when the health
  /// store refuses.
  Future<VitalsSnapshot> read();
}

/// Thrown when the health store will not give up its data.
class VitalsAccessException implements Exception {
  final String message;
  const VitalsAccessException(this.message);

  @override
  String toString() => message;
}
