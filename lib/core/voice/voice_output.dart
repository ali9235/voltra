/// VOLTRA // VOICE — speaking out loud, honestly.
///
/// Chain on this machine:
///   VOLTRA (Flutter, Windows) -> powershell.exe -> System.Speech (SAPI)
///   -> an installed SAPI voice -> the speakers.
///
/// Rules that must never be broken:
///   * VOLTRA speaks English. Only English. The SAPI voices installed on this
///     PC are David and Zira, both English, and there is no Arabic voice.
///     Arabic is NEVER transliterated into Latin letters to fake it — that
///     would be neither Arabic nor English, just noise.
///   * SAPI does not raise an error when asked for a voice that is not
///     installed. It returns immediately and plays silence. Silence that looks
///     like success is the exact failure this layer exists to catch: a voice is
///     chosen only from the list the platform actually reports, and a speak
///     call that returns implausibly fast is reported as suspect rather than
///     counted as spoken.
///   * If VOLTRA cannot speak, it says so on screen. It never pretends.
library;

/// Whether VOLTRA can speak right now, and if not, why not.
enum VoiceStatus {
  /// [VoiceOutput.probe] has not run yet. Nothing has been claimed either way.
  unknown,

  /// Working out what the platform can do.
  checking,

  /// A real, installed English voice was found. VOLTRA can speak.
  ready,

  /// Speaking right now.
  speaking,

  /// This platform has no speech engine VOLTRA can drive (the web build).
  unsupported,

  /// The engine is reachable but no English voice is installed, so anything
  /// VOLTRA "said" would be silence.
  noVoiceInstalled,

  /// The engine failed — PowerShell missing, blocked, or it returned an error.
  failed,
}

extension VoiceStatusInfo on VoiceStatus {
  /// True only when a real voice is available.
  bool get canSpeak =>
      this == VoiceStatus.ready || this == VoiceStatus.speaking;

  /// True when the user needs to be told something is wrong.
  bool get isProblem =>
      this == VoiceStatus.unsupported ||
      this == VoiceStatus.noVoiceInstalled ||
      this == VoiceStatus.failed;

  /// Short pill text. Uppercase, like every other status in VOLTRA.
  String get label => switch (this) {
    VoiceStatus.unknown => 'NOT CHECKED',
    VoiceStatus.checking => 'CHECKING',
    VoiceStatus.ready => 'VOICE READY',
    VoiceStatus.speaking => 'SPEAKING',
    VoiceStatus.unsupported => 'NO VOICE ON THIS PLATFORM',
    VoiceStatus.noVoiceInstalled => 'NO VOICE INSTALLED',
    VoiceStatus.failed => 'VOICE FAILED',
  };
}

/// One installed voice as the platform reports it.
class VoiceDescription {
  final String name;
  final String culture;

  const VoiceDescription({required this.name, required this.culture});

  /// True for any English culture: en-US, en-GB, en-AU and friends.
  bool get isEnglish => culture.toLowerCase().startsWith('en');

  /// "Microsoft David Desktop · en-US"
  String get readable => '$name · $culture';
}

/// What a probe found. Nothing here is a guess: every field either came from
/// the platform or is null.
class VoiceCapability {
  final VoiceStatus status;

  /// Every voice the platform reported, English or not.
  final List<VoiceDescription> voices;

  /// The voice VOLTRA will actually use, or null when there is none.
  final VoiceDescription? selected;

  /// Plain-English explanation, shown to the user when something is wrong.
  final String? detail;

  const VoiceCapability({
    required this.status,
    this.voices = const <VoiceDescription>[],
    this.selected,
    this.detail,
  });

  const VoiceCapability.unsupported(String reason)
    : status = VoiceStatus.unsupported,
      voices = const <VoiceDescription>[],
      selected = null,
      detail = reason;

  /// Voices VOLTRA could actually use.
  List<VoiceDescription> get englishVoices =>
      voices.where((v) => v.isEnglish).toList(growable: false);
}

/// The result of one attempt to speak.
class VoiceSpeakResult {
  final bool spoken;

  /// True when the engine claimed success but returned far too quickly for the
  /// words to have been said out loud. Treated as a failure worth reporting,
  /// because the alternative is VOLTRA silently believing it spoke.
  final bool suspectSilent;

  final String? detail;

  const VoiceSpeakResult._({
    required this.spoken,
    required this.suspectSilent,
    this.detail,
  });

  const VoiceSpeakResult.spoken() : this._(spoken: true, suspectSilent: false);

  const VoiceSpeakResult.suspect(String detail)
    : this._(spoken: false, suspectSilent: true, detail: detail);

  const VoiceSpeakResult.failed(String detail)
    : this._(spoken: false, suspectSilent: false, detail: detail);
}

/// Contract every speech backend must satisfy.
abstract class VoiceOutput {
  /// Human readable name of the backing engine.
  String get engineName;

  /// Ask the platform what it has. Must never throw.
  Future<VoiceCapability> probe();

  /// Say [text] out loud with [voice]. Must never throw.
  Future<VoiceSpeakResult> speak(String text, VoiceDescription voice);

  /// Stop mid-sentence. Must never throw.
  Future<void> stop();
}
