// The morning experience, tested where it actually matters.
//
// Four promises are made about the greeting, and three of them are promises
// about something NOT happening — which is exactly the kind of thing that
// quietly breaks. So they are pinned down here:
//
//   1. The wake time comes from the recorded sleep-end and nowhere else.
//   2. The greeting can never fire twice, in one session or across restarts.
//   3. The greeting can never fire for a previous day's wake.
//   4. A greeting missed because the PC was off is delivered at the next
//      launch rather than lost.
//
// The clock is injected, so none of this depends on what time the suite runs.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltra_app/core/context_engine/context_engine.dart';
import 'package:voltra_app/core/services/health_summary_service.dart';
import 'package:voltra_app/core/services/voice_service.dart';
import 'package:voltra_app/core/theme/voltra_palette.dart';

/// A health service that reports exactly the summary a test hands it, with no
/// network anywhere near it.
class FakeHealth extends HealthSummaryService {
  FakeHealth([this._summary]);

  HealthSummary? _summary;

  @override
  HealthSummary? get summary => _summary;

  void emit(HealthSummary? next) {
    _summary = next;
    notifyListeners();
  }
}

/// A voice backend that records what it was asked to say instead of saying it.
class RecordingVoice implements VoiceOutput {
  final List<String> spoken = <String>[];

  @override
  String get engineName => 'recording (test)';

  @override
  Future<VoiceCapability> probe() async => const VoiceCapability(
    status: VoiceStatus.ready,
    voices: <VoiceDescription>[
      VoiceDescription(name: 'Test Voice', culture: 'en-US'),
    ],
    selected: VoiceDescription(name: 'Test Voice', culture: 'en-US'),
  );

  @override
  Future<VoiceSpeakResult> speak(String text, VoiceDescription voice) async {
    spoken.add(text);
    return const VoiceSpeakResult.spoken();
  }

  @override
  Future<void> stop() async {}
}

/// A voice backend that behaves like SAPI asked for a voice it does not have:
/// it claims nothing went wrong and produces silence.
class SilentlyFailingVoice implements VoiceOutput {
  @override
  String get engineName => 'silent (test)';

  @override
  Future<VoiceCapability> probe() async => const VoiceCapability(
    status: VoiceStatus.noVoiceInstalled,
    detail: 'No English voice is installed on this machine.',
  );

  @override
  Future<VoiceSpeakResult> speak(String text, VoiceDescription voice) async =>
      const VoiceSpeakResult.suspect('Returned instantly without speaking.');

  @override
  Future<void> stop() async {}
}

/// Builds a summary carrying a real recorded night.
HealthSummary summaryWithSleep({
  required DateTime sleepStart,
  required DateTime sleepEnd,
  double? totalSleepHours,
  double? sevenDayAverage,
  double? restingHeartRate,
  double? hrv,
}) {
  String iso(DateTime t) => t.toIso8601String();

  return HealthSummary.fromJson(<String, dynamic>{
    'reference_date': iso(sleepEnd),
    'latest_sample_at': iso(sleepEnd),
    'available_metrics': <String>['sleep', 'resting_heart_rate', 'hrv'],
    'overview': <String, dynamic>{
      'sleep': <String, dynamic>{
        'sleep_start': iso(sleepStart),
        'sleep_end': iso(sleepEnd),
        'total_sleep_hours': totalSleepHours,
        'seven_day_average_sleep_hours': sevenDayAverage,
        'source': "Ali's Apple Watch",
      },
      if (restingHeartRate != null)
        'resting_heart_rate': <String, dynamic>{'latest': restingHeartRate},
      if (hrv != null) 'hrv': <String, dynamic>{'latest': hrv},
    },
  });
}

/// A summary with real metrics but no night in it at all.
HealthSummary summaryWithoutSleep(DateTime at) {
  return HealthSummary.fromJson(<String, dynamic>{
    'latest_sample_at': at.toIso8601String(),
    'available_metrics': <String>['resting_heart_rate'],
    'overview': <String, dynamic>{
      'resting_heart_rate': <String, dynamic>{'latest': 61},
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('wake detection', () {
    test('there is no wake, and no greeting, without a sleep record', () async {
      final now = DateTime(2026, 9, 25, 9, 30);
      final health = FakeHealth(summaryWithoutSleep(now));
      final engine = ContextEngine(health: health, clock: () => now);
      addTearDown(engine.dispose);

      await engine.load();

      expect(
        engine.snapshot.lastSleepEnd,
        isNull,
        reason: 'no sleep record means no wake time, not a guessed one',
      );
      expect(engine.pendingWake, isNull);
      expect(engine.shouldGreet, isFalse);
      expect(engine.brief, isNull);
    });

    test('the wake time is the recorded sleep-end, to the minute', () async {
      final wake = DateTime(2026, 9, 25, 11, 2);
      final now = DateTime(2026, 9, 25, 11, 20);
      final health = FakeHealth(
        summaryWithSleep(
          sleepStart: DateTime(2026, 9, 25, 3, 11),
          sleepEnd: wake,
          totalSleepHours: 7.85,
        ),
      );
      final engine = ContextEngine(health: health, clock: () => now);
      addTearDown(engine.dispose);

      await engine.load();

      expect(engine.snapshot.lastSleepEnd, wake);
      expect(engine.pendingWake, wake);
    });
  });

  group('the greeting fires exactly once', () {
    test('delivering it consumes it for the rest of the session', () async {
      final now = DateTime(2026, 9, 25, 11, 20);
      final recorder = RecordingVoice();
      final voice = VoiceService(output: recorder);
      final health = FakeHealth(
        summaryWithSleep(
          sleepStart: DateTime(2026, 9, 25, 3, 11),
          sleepEnd: DateTime(2026, 9, 25, 11, 2),
          totalSleepHours: 7.85,
        ),
      );
      final engine = ContextEngine(
        health: health,
        voice: voice,
        clock: () => now,
      );
      addTearDown(engine.dispose);

      await engine.load();
      await engine.deliverGreetingIfDue();

      expect(recorder.spoken, hasLength(1));
      expect(engine.shouldGreet, isFalse);
      expect(engine.brief, isNotNull);
      expect(engine.briefWasSpoken, isTrue);

      // Anything that nudges the engine again must not produce a second one.
      await engine.deliverGreetingIfDue();
      await engine.deliverGreetingIfDue();
      health.emit(health.summary);

      expect(
        recorder.spoken,
        hasLength(1),
        reason: 'the greeting must be impossible to fire twice',
      );
    });

    test('restarting VOLTRA on the same day does not repeat it', () async {
      final wake = DateTime(2026, 9, 25, 11, 2);
      final summary = summaryWithSleep(
        sleepStart: DateTime(2026, 9, 25, 3, 11),
        sleepEnd: wake,
        totalSleepHours: 7.85,
      );

      final firstRecorder = RecordingVoice();
      final first = ContextEngine(
        health: FakeHealth(summary),
        voice: VoiceService(output: firstRecorder),
        clock: () => DateTime(2026, 9, 25, 11, 20),
      );
      await first.load();
      await first.deliverGreetingIfDue();
      first.dispose();

      expect(firstRecorder.spoken, hasLength(1));

      // Same stored preferences, brand new engine: this is a restart.
      final secondRecorder = RecordingVoice();
      final second = ContextEngine(
        health: FakeHealth(summary),
        voice: VoiceService(output: secondRecorder),
        clock: () => DateTime(2026, 9, 25, 16, 45),
      );
      addTearDown(second.dispose);
      await second.load();
      await second.deliverGreetingIfDue();

      expect(
        secondRecorder.spoken,
        isEmpty,
        reason: 'a restart must not re-greet a wake already greeted',
      );
      expect(second.shouldGreet, isFalse);
      expect(
        second.brief,
        isNotNull,
        reason: 'the briefing should still be on screen after a restart',
      );
      expect(second.briefIsFromEarlier, isTrue);
    });

    test('a greeting recorded under the old day key is not repeated', () async {
      // Upgrading from the version that keyed the greeting on the date must
      // not hand Ali a second greeting for a morning already greeted.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'voltra.context.greetedOn': '2026-09-25',
      });

      final recorder = RecordingVoice();
      final engine = ContextEngine(
        health: FakeHealth(
          summaryWithSleep(
            sleepStart: DateTime(2026, 9, 25, 3, 11),
            sleepEnd: DateTime(2026, 9, 25, 11, 2),
            totalSleepHours: 7.85,
          ),
        ),
        voice: VoiceService(output: recorder),
        clock: () => DateTime(2026, 9, 25, 12, 0),
      );
      addTearDown(engine.dispose);

      await engine.load();
      await engine.deliverGreetingIfDue();

      expect(recorder.spoken, isEmpty);
      expect(engine.shouldGreet, isFalse);
    });
  });

  group('the greeting never belongs to a previous day', () {
    test("yesterday's wake gets no greeting today", () async {
      final recorder = RecordingVoice();
      final engine = ContextEngine(
        health: FakeHealth(
          summaryWithSleep(
            sleepStart: DateTime(2026, 9, 23, 23, 40),
            sleepEnd: DateTime(2026, 9, 24, 7, 15),
            totalSleepHours: 7.5,
          ),
        ),
        voice: VoiceService(output: recorder),
        clock: () => DateTime(2026, 9, 25, 9, 0),
      );
      addTearDown(engine.dispose);

      await engine.load();
      await engine.deliverGreetingIfDue();

      expect(engine.shouldGreet, isFalse);
      expect(recorder.spoken, isEmpty);
    });

    test('a sleep that ends in the future is bad data, not a wake', () async {
      final engine = ContextEngine(
        health: FakeHealth(
          summaryWithSleep(
            sleepStart: DateTime(2026, 9, 25, 3, 0),
            sleepEnd: DateTime(2026, 9, 25, 23, 0),
            totalSleepHours: 7.0,
          ),
        ),
        clock: () => DateTime(2026, 9, 25, 9, 0),
      );
      addTearDown(engine.dispose);

      await engine.load();

      expect(engine.pendingWake, isNull);
      expect(engine.shouldGreet, isFalse);
    });
  });

  group('a missed greeting is delivered, not lost', () {
    test('the PC being off at wake time only delays the greeting', () async {
      // Woke at 06:40. VOLTRA was closed. First launch is 21:15 — long past
      // the three-hour POST_SLEEP window, so this is exactly the case that the
      // old day-plus-window rule dropped on the floor.
      final wake = DateTime(2026, 9, 25, 6, 40);
      final launch = DateTime(2026, 9, 25, 21, 15);

      final recorder = RecordingVoice();
      final engine = ContextEngine(
        health: FakeHealth(
          summaryWithSleep(
            sleepStart: DateTime(2026, 9, 24, 23, 5),
            sleepEnd: wake,
            totalSleepHours: 7.5,
          ),
        ),
        voice: VoiceService(output: recorder),
        clock: () => launch,
      );
      addTearDown(engine.dispose);

      await engine.load();

      expect(
        engine.snapshot.isFreshlyAwake,
        isFalse,
        reason: 'fourteen hours awake is not POST_SLEEP',
      );
      expect(
        engine.shouldGreet,
        isTrue,
        reason: 'the greeting is still owed even though the window passed',
      );

      await engine.deliverGreetingIfDue();

      expect(recorder.spoken, hasLength(1));
      expect(engine.brief!.isLate, isTrue);
      expect(engine.brief!.wakeAt, wake);
      // Late or not, it must not claim to be morning at nine at night.
      expect(engine.brief!.opening, isNot(contains('Good morning')));
    });

    test('a wake arriving with a later health refresh is picked up', () async {
      final now = DateTime(2026, 9, 25, 11, 30);
      final recorder = RecordingVoice();
      final health = FakeHealth();
      final engine = ContextEngine(
        health: health,
        voice: VoiceService(output: recorder),
        clock: () => now,
      );
      addTearDown(engine.dispose);

      await engine.load();
      expect(engine.shouldGreet, isFalse, reason: 'no data has arrived yet');

      // The health server answers a moment after launch, as it does in life.
      health.emit(
        summaryWithSleep(
          sleepStart: DateTime(2026, 9, 25, 3, 11),
          sleepEnd: DateTime(2026, 9, 25, 11, 2),
          totalSleepHours: 7.85,
        ),
      );
      await pumpEventQueue();

      expect(
        recorder.spoken,
        hasLength(1),
        reason: 'the engine greets on its own, without Home asking it to',
      );
    });
  });

  group('what the briefing says', () {
    MorningBrief build({
      HealthOverview? overview,
      int scheduled = 0,
      String? nextTitle,
      DateTime? nextStart,
      DayPhase phase = DayPhase.morning,
    }) {
      return MorningBrief.build(
        wakeAt: DateTime(2026, 9, 25, 11, 2),
        now: DateTime(2026, 9, 25, 11, 3),
        phase: phase,
        name: 'Ali',
        overview: overview,
        scheduledToday: scheduled,
        nextEventTitle: nextTitle,
        nextEventStart: nextStart,
      );
    }

    test('the opening is the calm line, by name', () {
      expect(
        build().opening,
        'Good morning, Ali. Hope you slept well. '
        'What would you like to do today?',
      );
    });

    test('a missing metric produces no sentence rather than a zero', () {
      final brief = build(
        overview: HealthOverview.fromJson(<String, dynamic>{
          'sleep': <String, dynamic>{'sleep_end': '2026-09-25T11:02:00'},
        }),
      );

      // The opening says "hope you slept well" whatever the data shows — that
      // is a greeting, not a reading. What must not appear is a sentence built
      // from a metric that is missing.
      final facts = brief.details.join(' ').toLowerCase();

      expect(facts, isNot(contains('you slept')));
      expect(facts, isNot(contains('heart rate')));
      expect(facts, isNot(contains('hrv')));
      expect(
        facts,
        isNot(matches(RegExp(r'\d'))),
        reason: 'a missing metric must produce no number at all, not a zero',
      );
    });

    test('real sleep and vitals are read out in plain sentences', () {
      final brief = build(
        overview: HealthOverview.fromJson(<String, dynamic>{
          'sleep': <String, dynamic>{
            'total_sleep_hours': 7.4167,
            'seven_day_average_sleep_hours': 7.95,
          },
          'resting_heart_rate': <String, dynamic>{'latest': 61},
          'hrv': <String, dynamic>{'latest': 74},
        }),
      );

      expect(brief.details.first, contains('You slept 7 hours and 25 minutes'));
      expect(brief.details.first, contains('less than your usual'));
      expect(brief.spoken, contains('resting heart rate is 61'));
      expect(brief.spoken, contains('HRV is 74'));
    });

    test('an empty schedule is said plainly, not padded', () {
      expect(build().details, contains('Nothing is on your schedule today.'));
    });

    test("today's plan is one sentence with the next thing in it", () {
      final brief = build(
        scheduled: 3,
        nextTitle: 'Gym',
        nextStart: DateTime(2026, 9, 25, 17, 30),
      );

      expect(
        brief.details.last,
        'You have three things on today, starting with Gym '
        'at 5 30 in the evening.',
      );
    });

    test('the briefing stays short enough to be spoken', () {
      final brief = build(
        overview: HealthOverview.fromJson(<String, dynamic>{
          'sleep': <String, dynamic>{
            'total_sleep_hours': 7.4167,
            'seven_day_average_sleep_hours': 7.95,
          },
          'resting_heart_rate': <String, dynamic>{'latest': 61},
          'hrv': <String, dynamic>{'latest': 74},
        }),
        scheduled: 2,
        nextTitle: 'Study',
        nextStart: DateTime(2026, 9, 25, 14, 0),
      );

      expect(
        brief.details.length,
        lessThanOrEqualTo(3),
        reason: 'a spoken paragraph is a data dump with a voice',
      );
    });

    test('what is spoken and what is shown are the same words', () {
      final brief = build(scheduled: 0);
      expect(brief.spoken, '${brief.opening} ${brief.details.join(' ')}');
    });
  });

  group('when VOLTRA cannot speak', () {
    test('silence pretending to be success is reported as a problem', () async {
      final voice = VoiceService(output: SilentlyFailingVoice());
      await voice.initialize();

      expect(voice.status, VoiceStatus.noVoiceInstalled);
      expect(voice.problem, isNotNull);
      expect(voice.willSpeak, isFalse);

      final spoke = await voice.speak('anything');
      expect(spoke, isFalse);
      expect(voice.lastSpoken, isNull);
    });

    test('the briefing is still delivered on screen, silently', () async {
      final voice = VoiceService(output: SilentlyFailingVoice());
      final engine = ContextEngine(
        health: FakeHealth(
          summaryWithSleep(
            sleepStart: DateTime(2026, 9, 25, 3, 11),
            sleepEnd: DateTime(2026, 9, 25, 11, 2),
            totalSleepHours: 7.85,
          ),
        ),
        voice: voice,
        clock: () => DateTime(2026, 9, 25, 11, 20),
      );
      addTearDown(engine.dispose);

      await engine.load();
      await engine.deliverGreetingIfDue();

      expect(
        engine.brief,
        isNotNull,
        reason: 'no voice must not mean no briefing',
      );
      expect(engine.briefWasSpoken, isFalse);
      expect(
        voice.problem,
        isNotNull,
        reason: 'the UI needs something honest to show',
      );
    });

    test(
      'a voice with no English option is refused, never transliterated',
      () async {
        final capability = VoiceCapability(
          status: VoiceStatus.noVoiceInstalled,
          voices: const <VoiceDescription>[
            VoiceDescription(name: 'Microsoft Naayf', culture: 'ar-SA'),
          ],
          detail: 'No English voice installed.',
        );

        expect(capability.englishVoices, isEmpty);
        expect(capability.selected, isNull);
        expect(capability.voices.single.isEnglish, isFalse);
      },
    );
  });

  group('Morning Mode', () {
    test('a recorded wake turns on the bright palette', () {
      final palette = VoltraPalette.forContext(
        ContextSnapshot(
          at: DateTime(2026, 9, 25, 11, 20),
          phase: DayPhase.morning,
          activity: ActivityPhase.postSleep,
          activityConfidence: ActivityConfidence.measured,
          lastSleepEnd: DateTime(2026, 9, 25, 11, 2),
          awakeFor: const Duration(minutes: 18),
        ),
      );

      expect(palette.name, 'MORNING');
      expect(palette.isLight, isTrue);
      expect(palette.backgroundGradient, isNotNull);
    });

    test('waking late still gets Morning Mode, because the wake decides', () {
      final palette = VoltraPalette.forContext(
        ContextSnapshot(
          at: DateTime(2026, 9, 25, 13, 40),
          phase: DayPhase.day,
          activity: ActivityPhase.postSleep,
          activityConfidence: ActivityConfidence.measured,
          lastSleepEnd: DateTime(2026, 9, 25, 13, 20),
          awakeFor: const Duration(minutes: 20),
        ),
      );

      expect(palette.name, 'MORNING');
    });

    test('the rest of the day stays dark', () {
      for (final phase in DayPhase.values) {
        final palette = VoltraPalette.forContext(
          ContextSnapshot(
            at: DateTime(2026, 9, 25, 20),
            phase: phase,
            activity: ActivityPhase.restDay,
            activityConfidence: ActivityConfidence.assumed,
          ),
        );

        if (phase == DayPhase.morning) {
          expect(palette.isLight, isTrue);
        } else {
          expect(palette.isLight, isFalse, reason: '${phase.label} is dark');
        }
      }
    });

    test('the palette can interpolate into and out of Morning Mode', () {
      final half = VoltraPalette.night.lerp(VoltraPalette.morning, 0.5);

      expect(
        half.backgroundGradient,
        isNotNull,
        reason: 'the sunrise wash has to fade in, not appear at once',
      );
      expect(half.background, isNot(VoltraPalette.night.background));
    });
  });
}
