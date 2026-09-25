import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../voice/voice_output.dart';
import '../voice/voice_output_stub.dart'
    if (dart.library.io) '../voice/voice_output_io.dart';

export '../voice/voice_output.dart';

/// VOLTRA's voice, for the whole app.
///
/// Owns one question — "can VOLTRA speak, and did it actually speak?" — and
/// answers it honestly. There is no path through this class that leaves the UI
/// believing a line was said out loud when it was not: every failure ends up in
/// [problem], which Home and Settings both show.
class VoiceService extends ChangeNotifier {
  VoiceService({VoiceOutput? output})
    : _output = output ?? createPlatformVoiceOutput();

  final VoiceOutput? _output;

  static const String _kEnabled = 'voltra.voice.enabled';

  SharedPreferences? _prefs;
  VoiceCapability _capability = const VoiceCapability(
    status: VoiceStatus.unknown,
  );
  bool _enabled = true;
  bool _initialized = false;
  String? _lastSpoken;
  DateTime? _lastSpokenAt;
  String? _problem;

  /// What the platform can do. Never a guess.
  VoiceCapability get capability => _capability;

  VoiceStatus get status => _capability.status;

  /// Name of the engine behind the voice, for the diagnostics panel.
  String get engineName => _output?.engineName ?? 'none';

  /// Whether Ali wants VOLTRA to speak. Persisted.
  bool get enabled => _enabled;

  /// True only when a real voice exists AND speaking is switched on.
  bool get willSpeak => _enabled && _capability.status.canSpeak;

  /// The last line VOLTRA genuinely said out loud.
  String? get lastSpoken => _lastSpoken;
  DateTime? get lastSpokenAt => _lastSpokenAt;

  /// The one sentence to show the user when speech is not working. Null when
  /// there is nothing wrong. Covers both "no voice installed" and "the engine
  /// claimed success but produced silence".
  String? get problem => _problem;

  Future<void>? _initFuture;

  /// Probes once and remembers the attempt.
  ///
  /// Everything that is about to speak awaits this first, so a briefing that
  /// becomes due while the probe is still running waits the extra moment
  /// instead of being delivered silently and marked as done.
  Future<void> ensureInitialized() => _initFuture ??= initialize();

  /// Probes the platform. Safe to call again; it re-probes.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _enabled = _prefs?.getBool(_kEnabled) ?? true;

    final output = _output;
    if (output == null) {
      _capability = VoiceCapability.unsupported(platformVoiceUnavailableReason);
      _problem = platformVoiceUnavailableReason;
      _initialized = true;
      notifyListeners();
      return;
    }

    _capability = const VoiceCapability(status: VoiceStatus.checking);
    notifyListeners();

    _capability = await output.probe();
    _problem = _capability.status.isProblem ? _capability.detail : null;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    await _prefs?.setBool(_kEnabled, value);
    if (!value) await stop();
    notifyListeners();
  }

  /// Says [text] out loud.
  ///
  /// Returns true only when the words were really spoken. Returns false — and
  /// sets [problem] — for every other outcome, including the SAPI case where
  /// the engine reports success and plays silence.
  Future<bool> speak(String text) async {
    final output = _output;

    // Not probed yet means we do not know what this machine can do, and
    // guessing is exactly what this class refuses to do.
    if (!_initialized || output == null) return false;
    if (!_enabled) return false;

    final voice = _capability.selected;
    if (voice == null) {
      _problem =
          _capability.detail ??
          'VOLTRA has no usable English voice on this machine, so it cannot '
              'read the briefing out loud.';
      notifyListeners();
      return false;
    }

    _capability = VoiceCapability(
      status: VoiceStatus.speaking,
      voices: _capability.voices,
      selected: voice,
    );
    notifyListeners();

    final result = await output.speak(text, voice);

    _capability = VoiceCapability(
      status: result.spoken ? VoiceStatus.ready : VoiceStatus.failed,
      voices: _capability.voices,
      selected: voice,
      detail: result.detail,
    );

    if (result.spoken) {
      _lastSpoken = text;
      _lastSpokenAt = DateTime.now();
      _problem = null;
    } else {
      _problem = result.detail;
      if (kDebugMode) debugPrint('VOLTRA voice: ${result.detail}');
    }

    notifyListeners();
    return result.spoken;
  }

  Future<void> stop() async {
    await _output?.stop();
    if (_capability.status == VoiceStatus.speaking) {
      _capability = VoiceCapability(
        status: VoiceStatus.ready,
        voices: _capability.voices,
        selected: _capability.selected,
      );
      notifyListeners();
    }
  }
}
