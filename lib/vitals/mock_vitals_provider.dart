import 'dart:math';

import 'vitals_provider.dart';

/// Demo provider used on Web and Windows, where no health store exists.
///
/// This provider is NEVER selected on iOS. On iOS the app shows HealthKit
/// data or "NO DATA" — never these numbers.
///
/// Values are deterministic per calendar day so the UI does not jitter.
class MockVitalsProvider implements VitalsProvider {
  MockVitalsProvider();

  @override
  String get displayName => 'VOLTRA Demo Source';

  @override
  bool get providesRealData => false;

  @override
  String get statusDescription =>
      'Demo data. This platform has no Apple Health access.';

  @override
  Future<VitalsAccess> checkAccess() async => VitalsAccess.unsupported;

  @override
  Future<VitalsAccess> requestAccess() async => VitalsAccess.unsupported;

  @override
  Future<VitalsSnapshot> read() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final now = DateTime.now();
    final rnd = Random(now.year * 10000 + now.month * 100 + now.day);

    final steps = 6000 + rnd.nextInt(5000);
    final restingHr = 56 + rnd.nextInt(14).toDouble();

    return VitalsSnapshot(
      source: VitalsSource.demo,
      takenAt: now,
      steps: steps,
      sleepHours: 6.2 + rnd.nextDouble() * 2.2,
      restingHeartRate: restingHr,
      heartRate: restingHr + 8 + rnd.nextInt(25),
      workoutMinutes: rnd.nextInt(70),
      activeEnergyKcal: 280 + rnd.nextInt(420).toDouble(),
      distanceMeters: steps * 0.72,
    );
  }
}
