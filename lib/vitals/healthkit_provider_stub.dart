import 'vitals_provider.dart';

/// Web build. `dart:io` and the `health` plugin do not exist here, so there is
/// no health store to reach. Returns null -> the app falls back to the
/// Mock/Demo provider, which is always labelled DEMO.
VitalsProvider? createPlatformHealthProvider() => null;

/// Always false on Web.
bool get platformSupportsHealthKit => false;
