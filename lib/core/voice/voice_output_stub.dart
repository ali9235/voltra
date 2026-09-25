import 'voice_output.dart';

/// Web build. There is no `dart:io`, so there is no PowerShell and no SAPI.
///
/// Returns null so [VoiceService] reports [VoiceStatus.unsupported] rather
/// than inventing a speech engine that does not exist.
VoiceOutput? createPlatformVoiceOutput() => null;

/// Why speech is unavailable here. Shown to the user verbatim.
const String platformVoiceUnavailableReason =
    'VOLTRA can only speak in the native Windows app. The browser preview has '
    'no access to the Windows speech voices.';
