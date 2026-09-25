import '../core/context_engine/context_engine.dart';
import '../core/services/health_summary_service.dart';
import '../core/services/voice_service.dart';
import '../features/schedule/schedule_store.dart';
import '../services/desktop_link.dart';
import '../vitals/vitals_service.dart';

/// The long-lived objects every screen shares.
///
/// Deliberately plain: a handful of singletons created once in main(), passed
/// around by import. No dependency-injection framework for an app this size.

/// Link to VOLTRA Desktop (pairing server, port 8765).
final DesktopLink desktopLink = DesktopLink();

/// Platform vitals provider (HealthKit on iOS, demo elsewhere). Kept for the
/// iOS path; the Windows/web path reads from [healthSummary] instead.
final VitalsService vitalsService = VitalsService();

/// Apple Watch data from the local health server (port 8766).
final HealthSummaryService healthSummary = HealthSummaryService();

/// Ali's own schedule, stored on this machine.
final ScheduleStore scheduleStore = ScheduleStore();

/// VOLTRA's voice. English only — the SAPI voices on this PC are David and
/// Zira, and there is no Arabic voice to speak Arabic with.
final VoiceService voiceOut = VoiceService();

/// Presence engine: time of day, what Ali is doing, and the morning
/// experience. It owns wake detection and the once-per-wake greeting, and it
/// speaks through [voiceOut] and reads today's plan from [scheduleStore].
final ContextEngine contextEngine = ContextEngine(
  health: healthSummary,
  voice: voiceOut,
  schedule: _glanceAtSchedule,
);

/// Bridges [ScheduleStore] to the shape the briefing needs, so the context
/// engine does not have to know how the schedule is stored.
ScheduleGlance _glanceAtSchedule(DateTime day) {
  final today = scheduleStore.forDay(day);
  if (today.isEmpty) return ScheduleGlance.empty;

  final now = DateTime.now();
  final upcoming = today.where((e) => e.end.isAfter(now)).toList();
  final next = upcoming.isNotEmpty ? upcoming.first : null;

  return ScheduleGlance(
    count: today.length,
    nextTitle: next?.title,
    nextStart: next?.start,
  );
}
