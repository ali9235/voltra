import 'dart:convert';
import 'dart:io';

import 'voice_output.dart';

/// Native build. On Windows this drives SAPI through PowerShell's
/// `System.Speech` assembly; every other native platform has no engine VOLTRA
/// knows how to talk to, so it reports that plainly.
VoiceOutput? createPlatformVoiceOutput() {
  if (Platform.isWindows) return WindowsSapiVoice();
  return null;
}

const String platformVoiceUnavailableReason =
    'VOLTRA only knows how to speak on Windows. On this platform it stays '
    'silent and shows the morning briefing on screen instead.';

/// Speech through Windows SAPI.
///
/// Why PowerShell and not a plugin: `System.Speech` ships with Windows, so
/// there is nothing to install and nothing to keep up to date. The cost is one
/// short-lived process per utterance, which is fine for a handful of spoken
/// lines a day.
///
/// The text is never interpolated into a command line. It is written to a
/// UTF-8 temp file and read back inside PowerShell, so a briefing containing
/// quotes, dollar signs or backticks cannot turn into script.
class WindowsSapiVoice implements VoiceOutput {
  WindowsSapiVoice();

  @override
  String get engineName => 'Windows Speech (SAPI)';

  Process? _running;

  /// Words per minute SAPI reads at rate 0, used only to sanity-check that a
  /// speak call took a plausible amount of time. Deliberately conservative.
  static const double _wordsPerMinute = 170;

  /// Under this fraction of the plausible duration, the call did not really
  /// speak — it returned instantly and played silence.
  static const double _suspectThreshold = 0.35;

  static const Duration _probeTimeout = Duration(seconds: 20);

  @override
  Future<VoiceCapability> probe() async {
    // `flutter test` must never spawn a speech process: a test run that makes
    // the machine talk is a test run nobody will run twice.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return const VoiceCapability(
        status: VoiceStatus.unsupported,
        detail: 'Speech is disabled while running tests.',
      );
    }

    const script = r'''
$ErrorActionPreference = 'Stop'
try {
  Add-Type -AssemblyName System.Speech
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  foreach ($v in $synth.GetInstalledVoices()) {
    if ($v.Enabled) {
      $i = $v.VoiceInfo
      Write-Output ("VOICE`t" + $i.Name + "`t" + $i.Culture.Name)
    }
  }
  $synth.Dispose()
  Write-Output 'OK'
} catch {
  Write-Output ('ERR' + "`t" + $_.Exception.Message)
}
''';

    final ProcessResult result;
    try {
      result = await _runScript(script).timeout(_probeTimeout);
    } on Object catch (e) {
      return VoiceCapability(
        status: VoiceStatus.failed,
        detail:
            'VOLTRA could not start Windows PowerShell to reach the '
            'speech engine. $e',
      );
    }

    final stdoutText = '${result.stdout}';

    if (result.exitCode != 0 && !stdoutText.contains('VOICE\t')) {
      return VoiceCapability(
        status: VoiceStatus.failed,
        detail:
            'Windows PowerShell exited with code ${result.exitCode} while '
            'listing the speech voices. ${_firstLine('${result.stderr}')}',
      );
    }

    final errLine = stdoutText
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.startsWith('ERR\t'), orElse: () => '');

    if (errLine.isNotEmpty) {
      return VoiceCapability(
        status: VoiceStatus.failed,
        detail:
            'The Windows speech engine reported: '
            '${errLine.substring(4)}',
      );
    }

    final voices = <VoiceDescription>[];
    for (final line in stdoutText.split('\n')) {
      final parts = line.trim().split('\t');
      if (parts.length == 3 && parts[0] == 'VOICE') {
        voices.add(VoiceDescription(name: parts[1], culture: parts[2]));
      }
    }

    if (voices.isEmpty) {
      return const VoiceCapability(
        status: VoiceStatus.noVoiceInstalled,
        detail:
            'Windows reported no enabled speech voices at all, so VOLTRA '
            'would only produce silence. Add one under Settings > Time & '
            'language > Speech.',
      );
    }

    final selected = _pickEnglish(voices);

    if (selected == null) {
      return VoiceCapability(
        status: VoiceStatus.noVoiceInstalled,
        voices: voices,
        detail:
            'None of the installed voices speak English '
            '(${voices.map((v) => v.readable).join(', ')}). VOLTRA will not '
            'transliterate, so it stays silent and shows the briefing on '
            'screen instead.',
      );
    }

    return VoiceCapability(
      status: VoiceStatus.ready,
      voices: voices,
      selected: selected,
    );
  }

  /// Prefer a natural-sounding English voice, then any English voice. Never a
  /// non-English one: VOLTRA speaks English or it says nothing.
  static VoiceDescription? _pickEnglish(List<VoiceDescription> voices) {
    final english = voices.where((v) => v.isEnglish).toList();
    if (english.isEmpty) return null;

    // Zira reads a calm sentence better than David on this machine, so she is
    // the first choice where both are present.
    for (final wanted in const ['Zira', 'Aria', 'Jenny', 'Hazel', 'David']) {
      for (final v in english) {
        if (v.name.contains(wanted)) return v;
      }
    }
    return english.first;
  }

  @override
  Future<VoiceSpeakResult> speak(String text, VoiceDescription voice) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const VoiceSpeakResult.failed('There was nothing to say.');
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return const VoiceSpeakResult.failed(
        'Speech is disabled while running tests.',
      );
    }

    File? textFile;
    try {
      final dir = await Directory.systemTemp.createTemp('voltra_voice');
      textFile = File('${dir.path}${Platform.pathSeparator}line.txt');
      await textFile.writeAsString(trimmed, encoding: utf8, flush: true);

      // The text, the path and the voice name are passed as arguments and read
      // from a file. Nothing from the briefing is ever pasted into the script
      // body, so no wording can turn into PowerShell.
      const speakScript = r'''
$ErrorActionPreference = 'Stop'
try {
  $path = $args[0]
  $voiceName = $args[1]
  Add-Type -AssemblyName System.Speech
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $synth.SelectVoice($voiceName)
  $synth.Rate = -1
  $synth.Volume = 100
  $synth.Speak($text)
  $synth.Dispose()
  Write-Output 'SPOKEN'
} catch {
  Write-Output ('ERR' + "`t" + $_.Exception.Message)
}
''';

      final started = DateTime.now();
      final result = await _runScript(
        speakScript,
        arguments: [textFile.path, voice.name],
        keepHandle: true,
      );
      final elapsed = DateTime.now().difference(started);

      final out = '${result.stdout}';

      final errLine = out
          .split('\n')
          .map((l) => l.trim())
          .firstWhere((l) => l.startsWith('ERR\t'), orElse: () => '');

      if (errLine.isNotEmpty) {
        return VoiceSpeakResult.failed(
          'The Windows speech engine refused to speak: '
          '${errLine.substring(4)}',
        );
      }

      if (!out.contains('SPOKEN')) {
        return VoiceSpeakResult.failed(
          'Windows PowerShell exited with code ${result.exitCode} without '
          'speaking. ${_firstLine('${result.stderr}')}',
        );
      }

      // SAPI is happy to "succeed" instantly and play nothing. Compare how
      // long it took against how long these words take to say.
      final plausible = _plausibleDuration(trimmed);
      if (elapsed < plausible * _suspectThreshold) {
        return VoiceSpeakResult.suspect(
          'Windows reported the briefing as spoken but finished in '
          '${elapsed.inMilliseconds} ms, far too fast for '
          '${plausible.inSeconds} seconds of speech. The "${voice.name}" '
          'voice is most likely installed but not usable, so nothing was '
          'actually heard.',
        );
      }

      return const VoiceSpeakResult.spoken();
    } on Object catch (e) {
      return VoiceSpeakResult.failed(
        'VOLTRA could not reach the Windows speech engine. $e',
      );
    } finally {
      _running = null;
      try {
        await textFile?.parent.delete(recursive: true);
      } on Object {
        // A leftover temp file is not worth failing a briefing over.
      }
    }
  }

  static Duration _plausibleDuration(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final seconds = (words / _wordsPerMinute) * 60;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  Future<void> stop() async {
    final process = _running;
    _running = null;
    if (process == null) return;
    try {
      process.kill();
    } on Object {
      // Already gone.
    }
  }

  /// Writes [body] to a temp .ps1 and runs it. Using a file rather than
  /// `-Command` keeps quoting out of the picture entirely.
  Future<ProcessResult> _runScript(
    String body, {
    List<String> arguments = const <String>[],
    bool keepHandle = false,
  }) async {
    final dir = await Directory.systemTemp.createTemp('voltra_ps');
    final file = File('${dir.path}${Platform.pathSeparator}run.ps1');
    await file.writeAsString(body, encoding: utf8, flush: true);

    try {
      final process = await Process.start('powershell.exe', <String>[
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        file.path,
        ...arguments,
      ], runInShell: false);

      if (keepHandle) _running = process;

      final stdoutText = await process.stdout.transform(utf8.decoder).join();
      final stderrText = await process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      return ProcessResult(process.pid, exitCode, stdoutText, stderrText);
    } finally {
      try {
        await dir.delete(recursive: true);
      } on Object {
        // Windows sometimes still holds the script briefly. Harmless.
      }
    }
  }

  static String _firstLine(String text) {
    final line = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return line;
  }
}
