/// The presence model: what part of the day it is, and what Ali is doing
/// inside it. Every screen reads these two enums to decide what to surface
/// and how loud to be.
library;

/// Where we are in the day. Derived from the clock.
enum DayPhase { morning, day, evening, night }

/// What Ali is doing. Derived from real health data plus what he has told the
/// app. Never guessed from nothing: [ContextSnapshot.activityConfidence]
/// says how much of it is actually known.
enum ActivityPhase {
  /// Just woke up — the first launch after the latest recorded sleep ended.
  postSleep,

  /// A workout is coming up soon.
  preWorkout,

  /// A workout is running right now.
  workout,

  /// A workout finished recently.
  postWorkout,

  /// Between sessions, body still catching up.
  recovery,

  /// No training planned today.
  restDay,
}

extension DayPhaseLabel on DayPhase {
  String get label => switch (this) {
    DayPhase.morning => 'MORNING',
    DayPhase.day => 'DAY',
    DayPhase.evening => 'EVENING',
    DayPhase.night => 'NIGHT',
  };

  /// Greeting used across the app. One name, one spelling.
  String greetingFor(String name) => switch (this) {
    DayPhase.morning => 'Good morning, $name',
    DayPhase.day => 'Good afternoon, $name',
    DayPhase.evening => 'Good evening, $name',
    DayPhase.night => 'Still up, $name',
  };
}

extension ActivityPhaseLabel on ActivityPhase {
  String get label => switch (this) {
    ActivityPhase.postSleep => 'POST SLEEP',
    ActivityPhase.preWorkout => 'PRE WORKOUT',
    ActivityPhase.workout => 'WORKOUT',
    ActivityPhase.postWorkout => 'POST WORKOUT',
    ActivityPhase.recovery => 'RECOVERY',
    ActivityPhase.restDay => 'REST DAY',
  };
}

/// How sure the engine is about [ContextSnapshot.activity].
enum ActivityConfidence {
  /// Backed by real data — a recorded sleep end, a running session.
  measured,

  /// A reasonable default given the time of day. Said out loud as a default,
  /// never dressed up as a measurement.
  assumed,
}

/// One immutable reading of "where Ali is right now".
class ContextSnapshot {
  final DateTime at;
  final DayPhase phase;
  final ActivityPhase activity;
  final ActivityConfidence activityConfidence;

  /// End of the most recent recorded night, if the export has one.
  final DateTime? lastSleepEnd;

  /// Time since [lastSleepEnd]. Null when no sleep has ever been recorded.
  final Duration? awakeFor;

  const ContextSnapshot({
    required this.at,
    required this.phase,
    required this.activity,
    required this.activityConfidence,
    this.lastSleepEnd,
    this.awakeFor,
  });

  bool get isMeasured => activityConfidence == ActivityConfidence.measured;

  /// True while the morning briefing is still relevant.
  bool get isFreshlyAwake => activity == ActivityPhase.postSleep;

  /// Short line shown next to the greeting.
  String get description {
    if (activity == ActivityPhase.postSleep) {
      final awake = awakeFor;
      if (awake != null && awake.inMinutes >= 1) {
        final h = awake.inHours;
        final m = awake.inMinutes % 60;
        final since = h > 0 ? '${h}h ${m}m' : '${m}m';
        return 'Awake for $since';
      }
      return 'Just woke up';
    }
    return switch (activity) {
      ActivityPhase.preWorkout => 'Training coming up',
      ActivityPhase.workout => 'Session in progress',
      ActivityPhase.postWorkout => 'Session finished',
      ActivityPhase.recovery => 'Recovering',
      ActivityPhase.restDay => 'Rest day',
      ActivityPhase.postSleep => 'Just woke up',
    };
  }
}
