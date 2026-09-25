/// The morning briefing: what VOLTRA says out loud when Ali wakes up.
///
/// Built from three sources, all real:
///   * the recorded sleep from GET /health/summary,
///   * the vitals in that same summary,
///   * Ali's own schedule, typed in by him.
///
/// Rules:
///   * Every sentence is built from a value that exists. A missing metric
///     produces no sentence — never "0 steps", never "about 7 hours".
///   * Short and conversational. Three sentences at most after the opening,
///     because a spoken paragraph is a data dump with a voice.
///   * English only. The installed SAPI voices on this machine are English,
///     and Arabic is never transliterated into Latin letters to fake it.
library;

import '../models/health_summary.dart';
import 'context_state.dart';

/// One built briefing. Immutable, and the same text is spoken and shown, so
/// what Ali hears and what he reads can never drift apart.
class MorningBrief {
  /// The recorded end of sleep this briefing belongs to. Real data, always.
  final DateTime wakeAt;

  /// When the briefing was built — which is when it was delivered, not when
  /// the wake happened. The two differ when the PC was off at wake time.
  final DateTime builtAt;

  /// "Good morning, Ali. Hope you slept well. What would you like to do today?"
  final String opening;

  /// Optional short sentences: sleep, how the body looks, what today holds.
  final List<String> details;

  const MorningBrief({
    required this.wakeAt,
    required this.builtAt,
    required this.opening,
    this.details = const <String>[],
  });

  /// Everything, as one passage. This is what gets spoken.
  String get spoken => [opening, ...details].join(' ');

  /// True when the briefing arrived long after the wake it belongs to, which
  /// happens when VOLTRA was closed at wake time. Worth saying on screen so a
  /// late greeting does not look like a bug.
  bool get isLate => builtAt.difference(wakeAt) > const Duration(hours: 3);

  /// How late, for the on-screen note.
  Duration get lateBy => builtAt.difference(wakeAt);

  /// Builds the briefing for [wakeAt].
  ///
  /// [phase] only shapes the opening words: "Good morning" is right at 8am and
  /// wrong at 9pm, and VOLTRA would rather be accurate than scripted.
  static MorningBrief build({
    required DateTime wakeAt,
    required DateTime now,
    required DayPhase phase,
    required String name,
    HealthOverview? overview,
    int scheduledToday = 0,
    String? nextEventTitle,
    DateTime? nextEventStart,
  }) {
    return MorningBrief(
      wakeAt: wakeAt,
      builtAt: now,
      opening: _opening(phase: phase, name: name),
      details: _details(
        overview: overview,
        scheduledToday: scheduledToday,
        nextEventTitle: nextEventTitle,
        nextEventStart: nextEventStart,
      ),
    );
  }

  /// Calm and natural, the way a person would say it. Reuses the existing
  /// per-phase greeting so VOLTRA never says "good morning" at 11pm.
  static String _opening({required DayPhase phase, required String name}) {
    final hello = phase.greetingFor(name);
    return phase == DayPhase.morning
        ? '$hello. Hope you slept well. What would you like to do today?'
        : '$hello. Hope you slept well. '
              'This is the first time VOLTRA has seen you since you woke up. '
              'What would you like to do?';
  }

  static List<String> _details({
    HealthOverview? overview,
    int scheduledToday = 0,
    String? nextEventTitle,
    DateTime? nextEventStart,
  }) {
    final out = <String>[];

    final sleepLine = _sleepSentence(overview?.sleep);
    if (sleepLine != null) out.add(sleepLine);

    final bodyLine = _bodySentence(overview);
    if (bodyLine != null) out.add(bodyLine);

    final scheduleLine = _scheduleSentence(
      scheduledToday: scheduledToday,
      nextEventTitle: nextEventTitle,
      nextEventStart: nextEventStart,
    );
    if (scheduleLine != null) out.add(scheduleLine);

    return out;
  }

  /// "You slept 7 hours and 25 minutes, and that's about half an hour under
  /// your usual." Built only from numbers the export actually contains.
  static String? _sleepSentence(SleepSummary? sleep) {
    final hours = sleep?.totalSleepHours;
    if (sleep == null || hours == null) return null;

    final buffer = StringBuffer('You slept ${_spokenDuration(hours)}');

    final delta = sleep.deltaVsWeeklyAverage;
    if (delta != null) {
      final minutes = (delta * 60).round();
      if (minutes.abs() < 20) {
        buffer.write(', right about your usual.');
      } else if (minutes > 0) {
        buffer.write(
          ', which is ${_spokenMinutes(minutes.abs())} '
          'more than your usual.',
        );
      } else {
        buffer.write(
          ', which is ${_spokenMinutes(minutes.abs())} '
          'less than your usual.',
        );
      }
    } else {
      buffer.write('.');
    }

    return buffer.toString();
  }

  /// "Your resting heart rate is 61 and your HRV is 74." Stated, not judged —
  /// VOLTRA does not tell Ali he is recovered when it cannot know that.
  static String? _bodySentence(HealthOverview? overview) {
    if (overview == null) return null;

    final resting = overview.restingHeartRate?.latest;
    final hrv = overview.hrv?.latest;

    if (resting != null && hrv != null) {
      return 'Your resting heart rate is ${resting.round()} '
          'and your HRV is ${hrv.round()}.';
    }
    if (resting != null) {
      return 'Your resting heart rate is ${resting.round()}.';
    }
    if (hrv != null) {
      return 'Your HRV is ${hrv.round()}.';
    }
    return null;
  }

  static String? _scheduleSentence({
    int scheduledToday = 0,
    String? nextEventTitle,
    DateTime? nextEventStart,
  }) {
    if (scheduledToday <= 0) {
      return 'Nothing is on your schedule today.';
    }

    final count = scheduledToday == 1
        ? 'one thing'
        : '${_spokenCount(scheduledToday)} things';

    if (nextEventTitle != null && nextEventStart != null) {
      return 'You have $count on today, starting with $nextEventTitle '
          'at ${_spokenClock(nextEventStart)}.';
    }
    return 'You have $count on your schedule today.';
  }

  /// "7 hours and 25 minutes" — written the way it is read aloud, so SAPI does
  /// not have to interpret "7h 25m".
  static String _spokenDuration(double hours) {
    final total = (hours * 60).round();
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return _spokenMinutes(m);
    final hourWord = h == 1 ? '1 hour' : '$h hours';
    if (m == 0) return hourWord;
    return '$hourWord and ${_spokenMinutes(m)}';
  }

  static String _spokenMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      final hourWord = h == 1 ? '1 hour' : '$h hours';
      return m == 0 ? hourWord : '$hourWord and $m minutes';
    }
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  static const List<String> _numberWords = <String>[
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
  ];

  static String _spokenCount(int value) =>
      value >= 0 && value < _numberWords.length
      ? _numberWords[value]
      : value.toString();

  /// "5:30 in the afternoon" reads better out loud than "17:30".
  static String _spokenClock(DateTime time) {
    final local = time.toLocal();
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute;

    final partOfDay = switch (hour24) {
      < 12 => 'in the morning',
      < 17 => 'in the afternoon',
      < 21 => 'in the evening',
      _ => 'tonight',
    };

    final clock = minute == 0
        ? '$hour12'
        : '$hour12 ${minute.toString().padLeft(2, '0')}';

    return '$clock $partOfDay';
  }
}
