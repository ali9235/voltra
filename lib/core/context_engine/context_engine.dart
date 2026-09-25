import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/health_summary_service.dart';
import '../services/voice_service.dart';
import 'context_state.dart';
import 'morning_brief.dart';

export 'context_state.dart';
export 'morning_brief.dart';

/// Reads Ali's schedule for the briefing without the context engine needing to
/// know how the schedule is stored.
typedef ScheduleLookup = ScheduleGlance Function(DateTime day);

/// The little the briefing needs to know about today's plan.
class ScheduleGlance {
  final int count;
  final String? nextTitle;
  final DateTime? nextStart;

  const ScheduleGlance({this.count = 0, this.nextTitle, this.nextStart});

  static const ScheduleGlance empty = ScheduleGlance();
}

/// Works out where Ali is in his day, keeps the rest of the app informed, and
/// owns the morning experience end to end.
///
/// Two inputs only: the clock, and the real sleep record from the health
/// server. Anything it cannot measure is marked [ActivityConfidence.assumed]
/// so no screen presents a default as a reading.
///
/// The morning greeting lives here rather than in a screen or a separate
/// "morning" subsystem, because waking up is a change of context and this is
/// the thing that understands context. Home renders what this decided; it does
/// not decide anything itself.
class ContextEngine extends ChangeNotifier {
  ContextEngine({
    required this.health,
    this.voice,
    this.schedule,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    health.addListener(_recompute);
  }

  final HealthSummaryService health;

  /// Reads the current time. Injectable so the wake rules — "never twice",
  /// "never a previous day's wake", "deliver a missed greeting on the next
  /// launch" — can be tested at a fixed moment instead of depending on what
  /// time of day the test suite happens to run.
  final DateTime Function() _clock;

  /// Speaks the briefing. Optional: without it VOLTRA still shows the briefing
  /// on screen, it just stays quiet.
  final VoiceService? voice;

  /// Today's plan, for the last sentence of the briefing.
  final ScheduleLookup? schedule;

  /// Wake day the greeting has already been delivered for. Keyed on the
  /// calendar day the sleep ENDED, not on today, and not on the exact instant:
  /// Health Auto Export can revise a night's sleep_end by a minute or two when
  /// a later export lands, and an instant-keyed record would let that count as
  /// a brand new wake and greet Ali twice.
  static const String _kGreetedForWakeDay = 'voltra.context.greetedForWakeDay';

  /// The original day-keyed record, from before the greeting followed the wake
  /// rather than the date. Read once so upgrading does not re-greet a day that
  /// was already greeted.
  static const String _kLegacyGreetedOn = 'voltra.context.greetedOn';

  static const String _kBriefOpening = 'voltra.context.brief.opening';
  static const String _kBriefDetails = 'voltra.context.brief.details';
  static const String _kBriefWakeAt = 'voltra.context.brief.wakeAt';
  static const String _kBriefBuiltAt = 'voltra.context.brief.builtAt';

  /// A night counts as "this morning" for this long after it ended. Drives the
  /// POST_SLEEP state and the palette — NOT whether the greeting is owed.
  static const Duration postSleepWindow = Duration(hours: 3);

  late ContextSnapshot _snapshot = ContextSnapshot(
    at: _clock(),
    phase: _phaseFor(_clock()),
    activity: ActivityPhase.restDay,
    activityConfidence: ActivityConfidence.assumed,
  );

  SharedPreferences? _prefs;
  String? _greetedForWakeDay;
  Timer? _tick;
  bool _loaded = false;
  bool _disposed = false;

  /// The delivery currently running, if any. Held so a second trigger joins the
  /// first instead of starting another one — and so callers can await the
  /// greeting rather than hoping it finished.
  Future<void>? _delivery;

  MorningBrief? _brief;
  String? _restoredBriefText;

  ContextSnapshot get snapshot => _snapshot;
  DayPhase get phase => _snapshot.phase;
  ActivityPhase get activity => _snapshot.activity;

  /// The name VOLTRA addresses. Single source of truth so no screen invents
  /// a different one.
  static const String userName = 'Ali';

  String get greeting => _snapshot.phase.greetingFor(userName);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    _greetedForWakeDay =
        _prefs?.getString(_kGreetedForWakeDay) ??
        _prefs?.getString(_kLegacyGreetedOn);

    _restoreBrief();
    _loaded = true;

    _recompute();
    // A minute is fine: nothing here changes faster than that.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
  }

  // ---------------------------------------------------------------------------
  // Wake detection and the once-per-wake guarantee
  // ---------------------------------------------------------------------------

  /// The wake VOLTRA still owes a greeting for, or null.
  ///
  /// Derived only from the recorded sleep-end time in the health export. If
  /// there is no sleep record there is no wake, and therefore no greeting —
  /// VOLTRA does not infer a wake time from the clock, from when the PC booted,
  /// or from anything else.
  ///
  /// It cannot fire twice, because delivery persists the wake's calendar day
  /// and this returns null for a day already recorded. It cannot fire for a
  /// previous day's wake, because the recorded sleep-end must fall on today's
  /// local calendar day.
  DateTime? get pendingWake {
    if (!_loaded) return null;

    final wake = _snapshot.lastSleepEnd;
    if (wake == null) return null;

    final now = _snapshot.at;

    // A sleep that ends in the future is bad data, not a wake.
    if (wake.isAfter(now)) return null;

    // Yesterday's wake is gone. Ali gets one greeting per morning, on that
    // morning — not a backlog when he opens VOLTRA on Thursday.
    if (!_isSameLocalDay(wake, now)) return null;

    return _greetedForWakeDay == _dayKey(wake) ? null : wake;
  }

  /// True when the morning briefing has not been delivered for today's wake
  /// yet. Reading it does not consume it.
  bool get shouldGreet => pendingWake != null;

  /// The briefing that was delivered for today's wake, or null.
  ///
  /// Survives a restart: the text is persisted with the wake it belongs to, so
  /// reopening VOLTRA at lunchtime still shows this morning's briefing without
  /// saying it again.
  MorningBrief? get brief => _brief;

  /// True when the briefing on screen was genuinely said out loud in this
  /// session. Two nulls are not a match: no briefing means nothing was spoken.
  bool get briefWasSpoken {
    final current = _brief;
    if (current == null) return false;
    return voice?.lastSpoken == current.spoken;
  }

  /// Marks the current wake's greeting as delivered.
  ///
  /// Persisting happens BEFORE anything is spoken, so a crash or a closed lid
  /// halfway through the sentence cannot produce a second greeting later.
  /// [forWake] is passed explicitly by the delivery path so that a health
  /// refresh landing mid-delivery cannot make this record the wrong wake.
  Future<void> markGreeted({DateTime? forWake}) async {
    final wake = forWake ?? _snapshot.lastSleepEnd;
    if (wake == null) return;
    final key = _dayKey(wake);
    if (_greetedForWakeDay == key) return;
    _greetedForWakeDay = key;
    await _prefs?.setString(_kGreetedForWakeDay, key);
    _notify();
  }

  /// Delivers the briefing if one is owed: builds it from real data, records it
  /// as delivered, then speaks it.
  ///
  /// Called on every recompute, so a wake that arrives with a later health
  /// refresh is picked up without Home having to watch for it — and a wake that
  /// happened while the PC was off is delivered on the first recompute after
  /// launch instead of being lost.
  /// Returns the delivery in progress when one is already running, so a second
  /// trigger joins it rather than racing it, and so awaiting this genuinely
  /// means "the greeting has been delivered".
  Future<void> deliverGreetingIfDue() {
    return _delivery ??= _deliver().whenComplete(() => _delivery = null);
  }

  Future<void> _deliver() async {
    final wake = pendingWake;
    if (wake == null) return;

    // The voice probe runs at startup and takes a moment. Wait for it, or a
    // briefing that becomes due in that window would be recorded as delivered
    // and never actually said.
    await voice?.ensureInitialized();
    if (_disposed) return;

    final built = _buildBrief(wake);

    // Recorded first. Speaking is best-effort; remembering is not.
    await markGreeted(forWake: wake);
    await _saveBrief(built);
    if (_disposed) return;

    _brief = built;
    _restoredBriefText = null;
    _notify();

    await voice?.speak(built.spoken);
    _notify();
  }

  /// Says the current briefing again, because Ali asked. An explicit replay is
  /// not a second automatic greeting, so it does not touch the delivery record.
  Future<void> replayBriefing() async {
    final current = _brief;
    if (current == null) return;
    await voice?.speak(current.spoken);
    _notify();
  }

  MorningBrief _buildBrief(DateTime wake) {
    final glance = schedule?.call(_clock()) ?? ScheduleGlance.empty;

    return MorningBrief.build(
      wakeAt: wake,
      now: _clock(),
      phase: _snapshot.phase,
      name: userName,
      overview: health.summary?.overview,
      scheduledToday: glance.count,
      nextEventTitle: glance.nextTitle,
      nextEventStart: glance.nextStart,
    );
  }

  Future<void> _saveBrief(MorningBrief brief) async {
    await _prefs?.setString(_kBriefOpening, brief.opening);
    await _prefs?.setStringList(_kBriefDetails, brief.details);
    await _prefs?.setString(_kBriefWakeAt, brief.wakeAt.toIso8601String());
    await _prefs?.setString(_kBriefBuiltAt, brief.builtAt.toIso8601String());
  }

  /// Brings back a briefing delivered earlier today so the Home card is still
  /// there after a restart. Only today's: a stored briefing from a previous
  /// wake is dropped rather than shown as if it were this morning's.
  void _restoreBrief() {
    final opening = _prefs?.getString(_kBriefOpening);
    final wakeRaw = _prefs?.getString(_kBriefWakeAt);
    final builtRaw = _prefs?.getString(_kBriefBuiltAt);
    if (opening == null || wakeRaw == null) return;

    final wake = DateTime.tryParse(wakeRaw);
    if (wake == null) return;
    if (!_isSameLocalDay(wake, _clock())) return;

    final details = _prefs?.getStringList(_kBriefDetails) ?? const <String>[];

    _restoredBriefText = opening;
    _brief = MorningBrief(
      wakeAt: wake,
      builtAt: DateTime.tryParse(builtRaw ?? '') ?? wake,
      opening: opening,
      details: details,
    );
  }

  /// True when the briefing on screen was read back from storage rather than
  /// built and spoken in this session.
  bool get briefIsFromEarlier => _restoredBriefText != null;

  // ---------------------------------------------------------------------------
  // The presence model
  // ---------------------------------------------------------------------------

  void _recompute() {
    final now = _clock();
    final sleepEnd = health.summary?.overview.sleep?.sleepEnd?.toLocal();
    final awakeFor = sleepEnd == null ? null : now.difference(sleepEnd);

    final ActivityPhase activity;
    final ActivityConfidence confidence;

    if (awakeFor != null &&
        !awakeFor.isNegative &&
        awakeFor <= postSleepWindow) {
      // Measured: there is a real sleep record and it ended recently.
      activity = ActivityPhase.postSleep;
      confidence = ActivityConfidence.measured;
    } else {
      // No session tracking exists yet, so VOLTRA does not pretend to know
      // whether Ali is training. Training will set this once it does.
      activity = ActivityPhase.restDay;
      confidence = ActivityConfidence.assumed;
    }

    final next = ContextSnapshot(
      at: now,
      phase: _phaseFor(now),
      activity: activity,
      activityConfidence: confidence,
      lastSleepEnd: sleepEnd,
      awakeFor: awakeFor != null && !awakeFor.isNegative ? awakeFor : null,
    );

    final changed =
        next.phase != _snapshot.phase ||
        next.activity != _snapshot.activity ||
        next.lastSleepEnd != _snapshot.lastSleepEnd;

    _snapshot = next;
    if (changed) _notify();

    // Deliberately after the snapshot is in place: the briefing is built from
    // the new context, not the old one. Not awaited — _recompute is called from
    // a timer and from a listener, neither of which can wait — but the future
    // is held in _delivery so anything that needs to can await it.
    if (!_disposed && shouldGreet) unawaited(deliverGreetingIfDue());
  }

  static DayPhase _phaseFor(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return DayPhase.morning;
    if (h >= 12 && h < 17) return DayPhase.day;
    if (h >= 17 && h < 22) return DayPhase.evening;
    return DayPhase.night;
  }

  static bool _isSameLocalDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static String _dayKey(DateTime t) {
    final local = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  /// notifyListeners, but safe after dispose.
  ///
  /// Delivering a greeting is asynchronous — it waits on the voice probe, on
  /// shared_preferences and on the speech engine — so it can still be in flight
  /// when VOLTRA is closed. Without this guard that lands as "a ContextEngine
  /// was used after being disposed" on shutdown.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    health.removeListener(_recompute);
    super.dispose();
  }
}
