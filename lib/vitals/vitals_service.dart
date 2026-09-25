import 'package:flutter/foundation.dart';

import 'healthkit_provider_stub.dart'
    if (dart.library.io) 'healthkit_provider_io.dart';
import 'mock_vitals_provider.dart';
import 'vitals_provider.dart';

export 'vitals_provider.dart';

/// Picks the right vitals source for the current platform and holds the
/// latest reading.
///
///   iOS                  -> HealthKit. Real data or nothing. Never demo.
///   Web / Windows / rest -> Mock/Demo, always labelled DEMO.
///
/// The one rule this class exists to enforce: a real provider is NEVER
/// silently swapped for the demo provider. If HealthKit fails, the user is
/// told it failed — they are not handed invented numbers.
class VitalsService extends ChangeNotifier {
  VitalsService({VitalsProvider? provider})
    : _provider = provider ?? _resolveProvider();

  final VitalsProvider _provider;

  VitalsSnapshot? _snapshot;
  VitalsAccess _access = VitalsAccess.notDetermined;
  bool _loading = false;
  String? _error;

  VitalsProvider get provider => _provider;
  VitalsSnapshot? get snapshot => _snapshot;
  VitalsAccess get access => _access;
  bool get loading => _loading;
  String? get error => _error;

  /// True when this platform can reach a real health store.
  bool get usesRealSource => _provider.providesRealData;

  /// True only when we are actually showing genuine device data.
  bool get isRealData => _snapshot?.source.isReal ?? false;

  /// True when the user still has to go through the permission sheet.
  bool get needsPermission => usesRealSource && _access != VitalsAccess.granted;

  /// Banner text. Blunt on purpose.
  String get sourceBanner {
    if (!usesRealSource) return 'DEMO DATA — not from Apple Health';
    return switch (_access) {
      VitalsAccess.granted => 'Live data — Apple Health',
      VitalsAccess.denied => 'Apple Health access denied',
      VitalsAccess.notDetermined => 'Apple Health access required',
      VitalsAccess.unsupported => 'Apple Health unavailable on this device',
    };
  }

  static VitalsProvider _resolveProvider() {
    if (kIsWeb) return MockVitalsProvider();
    final platformProvider = createPlatformHealthProvider();
    // Only a provider that serves real data may replace the demo provider.
    if (platformProvider != null && platformProvider.providesRealData) {
      return platformProvider;
    }
    return MockVitalsProvider();
  }

  /// Ask the platform for permission, then load.
  Future<void> requestAccessAndRefresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _access = await _provider.requestAccess();
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (usesRealSource && _access != VitalsAccess.granted) {
        _access = await _provider.checkAccess();
      }

      _snapshot = await _provider.read();

      // HealthKit never admits that a READ permission was refused — Apple
      // considers that a leak. An empty result is therefore ambiguous: either
      // the user recorded nothing, or access was silently withheld. Say so
      // rather than guessing.
      if (usesRealSource && _snapshot!.isEmpty) {
        _error =
            'Apple Health returned no data for any metric. Either there '
            'is nothing recorded for today, or VOLTRA was not granted access '
            'in Settings > Health > Data Access & Devices > VOLTRA.';
      }
    } on VitalsAccessException catch (e) {
      // Do NOT fall back to demo data on a real platform.
      _snapshot = null;
      _access = VitalsAccess.denied;
      _error = e.message;
    } catch (e) {
      _snapshot = null;
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
