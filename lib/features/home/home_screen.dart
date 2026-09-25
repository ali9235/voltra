import 'package:flutter/material.dart';

import '../../app/voltra_modules.dart';
import '../../app/voltra_services.dart';
import '../../core/context_engine/context_engine.dart';
import '../../core/health_format.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/health_state_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/voltra_card.dart';
import '../insights/insight_builder.dart';
import '../schedule/schedule_store.dart';

/// The first screen: who Ali is today, what his body is saying, and what is
/// next. Everything on it links into the module that owns it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenModule});

  final ValueChanged<VoltraModule> onOpenModule;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Home does not decide when the morning briefing happens. ContextEngine owns
  // wake detection and delivery, because a greeting that depended on this
  // screen being built would be lost the moment Ali opened VOLTRA on Sleep or
  // Training instead. Home renders whatever the engine decided.

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        healthSummary,
        contextEngine,
        scheduleStore,
      ]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
          children: [
            const _Greeting(),
            const _MorningBriefCard(),
            const SizedBox(height: 24),
            _vitalsCard(context),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _todayCard(context)),
                const SizedBox(width: 18),
                Expanded(child: _trainingCard(context)),
              ],
            ),
            const SizedBox(height: 18),
            _insightCard(context),
            const SizedBox(height: 18),
            _chatCard(context),
          ],
        );
      },
    );
  }

  Widget _vitalsCard(BuildContext context) {
    final summary = healthSummary.summary;

    if (!healthSummary.hasData || summary == null) {
      return HealthStatusView.placeholder(context, healthSummary);
    }

    final overview = summary.overview;
    final sleep = overview.sleep;

    return VoltraCard(
      title: 'Today',
      icon: Icons.monitor_heart_outlined,
      trailing: TextButton(
        onPressed: () => widget.onOpenModule(VoltraModule.health),
        child: const Text('Open Health'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...HealthStatusView.notices(context, healthSummary),
          MetricGrid(
            tiles: [
              MetricTile(
                label: 'Sleep',
                value: formatHours(sleep?.totalSleepHours),
                emphasis: true,
                context1: sleep?.sleepStart != null && sleep?.sleepEnd != null
                    ? '${formatClock(sleep!.sleepStart)} → '
                          '${formatClock(sleep.sleepEnd)}'
                    : null,
                context2: sleep?.sevenDayAverageSleepHours != null
                    ? '7-day avg '
                          '${formatHours(sleep!.sevenDayAverageSleepHours)}'
                    : null,
                missingReason: 'no night recorded in this export',
              ),
              MetricTile(
                label: 'Heart rate',
                value: formatBpm(overview.heartRate?.latest),
                emphasis: true,
                context1: overview.heartRate?.latestAt != null
                    ? 'latest · ${formatAge(DateTime.now().difference(overview.heartRate!.latestAt!.toLocal()))}'
                    : null,
                context2: overview.heartRate?.todayMin != null
                    ? 'today ${overview.heartRate!.todayMin!.round()}–'
                          '${overview.heartRate!.todayMax!.round()} bpm'
                    : null,
              ),
              MetricTile(
                label: 'Resting HR',
                value: formatBpm(overview.restingHeartRate?.latest),
                emphasis: true,
                context1: overview.restingHeartRate?.sevenDayAverage != null
                    ? '7-day avg '
                          '${formatBpm(overview.restingHeartRate!.sevenDayAverage)}'
                    : null,
              ),
              MetricTile(
                label: 'HRV',
                value: formatMs(overview.hrv?.latest),
                emphasis: true,
                context1: overview.hrv?.sevenDayAverage != null
                    ? '7-day avg ${formatMs(overview.hrv!.sevenDayAverage)}'
                    : null,
              ),
              MetricTile(
                label: 'Steps',
                value: formatSteps(overview.steps?.todayTotal),
                emphasis: true,
                context1: overview.steps?.sevenDayDailyAverage != null
                    ? 'daily avg '
                          '${formatSteps(overview.steps!.sevenDayDailyAverage)}'
                    : null,
                missingReason: 'no samples today yet',
              ),
              MetricTile(
                label: 'Active energy',
                value: formatKcal(overview.activeEnergy?.todayKcal),
                emphasis: true,
                context1:
                    overview.activeEnergy?.sevenDayDailyAverageKcal != null
                    ? 'daily avg '
                          '${formatKcal(overview.activeEnergy!.sevenDayDailyAverageKcal)}'
                    : null,
                missingReason: 'no samples today yet',
              ),
            ],
          ),
          HealthStatusView.sourceFooter(context, healthSummary),
        ],
      ),
    );
  }

  Widget _todayCard(BuildContext context) {
    final p = context.palette;
    final today = scheduleStore.forDay(DateTime.now());
    final next = scheduleStore.next;

    return VoltraCard(
      title: 'Schedule',
      icon: Icons.calendar_today_outlined,
      trailing: TextButton(
        onPressed: () => widget.onOpenModule(VoltraModule.schedule),
        child: const Text('Open'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (today.isEmpty)
            Text(
              'Nothing scheduled for today. Add your first block in Schedule '
              'and it will show up here.',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            )
          else ...[
            for (final event in today.take(4))
              FactRow(
                '${formatClock(event.start)}  ${event.title}',
                event.category.label,
              ),
            if (today.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${today.length - 4} more today',
                  style: TextStyle(color: p.textMuted, fontSize: 11.5),
                ),
              ),
          ],
          if (next != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXT', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 5),
                  Text(
                    next.title,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatClock(next.start)} – ${formatClock(next.end)}',
                    style: TextStyle(color: p.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trainingCard(BuildContext context) {
    final p = context.palette;
    final overview = healthSummary.summary?.overview;

    return VoltraCard(
      title: 'Training',
      icon: Icons.fitness_center_outlined,
      trailing: TextButton(
        onPressed: () => widget.onOpenModule(VoltraModule.training),
        child: const Text('Open'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No workout planned for today.',
            style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          Text(
            'READINESS SIGNALS',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          FactRow(
            'Sleep last night',
            formatHours(overview?.sleep?.totalSleepHours),
          ),
          FactRow('HRV', formatMs(overview?.hrv?.latest)),
          FactRow('Resting HR', formatBpm(overview?.restingHeartRate?.latest)),
          FactRow(
            'Exercise today',
            formatMinutes(overview?.exerciseTime?.todayTotal),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(BuildContext context) {
    final p = context.palette;
    final insights = InsightBuilder.build(
      summary: healthSummary.summary,
      series: healthSummary.series,
    );

    return VoltraCard(
      title: 'Insight',
      icon: Icons.insights_outlined,
      trailing: TextButton(
        onPressed: () => widget.onOpenModule(VoltraModule.insights),
        child: const Text('See all'),
      ),
      child: insights.isEmpty
          ? Text(
              'VOLTRA needs a few more days of exported data before it can '
              'compare today with your usual.',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final insight in insights.take(2))
                  ReadingLine(
                    insight.text,
                    tone: switch (insight.tone) {
                      InsightTone.good => p.positive,
                      InsightTone.watch => p.warning,
                      InsightTone.neutral => p.accent,
                    },
                  ),
              ],
            ),
    );
  }

  Widget _chatCard(BuildContext context) {
    final p = context.palette;

    return GestureDetector(
      onTap: () => widget.onOpenModule(VoltraModule.chat),
      behavior: HitTestBehavior.opaque,
      child: VoltraCard(
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 18, color: p.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask VOLTRA',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Questions answered from your own data — "how did I sleep '
                    'this week?", "should I train hard today?"',
                    style: TextStyle(color: p.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Greeting plus the current context state.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: Listenable.merge([contextEngine, healthSummary]),
      builder: (context, _) {
        final snapshot = contextEngine.snapshot;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contextEngine.greeting,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                StatusChip(label: snapshot.phase.label, color: p.accent),
                const SizedBox(width: 8),
                StatusChip(
                  label: snapshot.activity.label,
                  color: snapshot.isMeasured ? p.positive : p.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.description,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// This morning's briefing, exactly as VOLTRA said it.
///
/// Shown only when there is a real briefing to show, which means only when
/// there was a real recorded wake. No sleep record, no card — VOLTRA does not
/// put up an empty morning panel to fill the space.
class _MorningBriefCard extends StatelessWidget {
  const _MorningBriefCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([contextEngine, voiceOut, healthSummary]),
      builder: (context, _) {
        final brief = contextEngine.brief;

        if (brief == null) {
          // A briefing needs a recorded wake. When the export has arrived but
          // carries no night, say that — do not invent a wake time, and do not
          // leave a silent gap that looks like a bug.
          final hasSleep =
              healthSummary.summary?.overview.sleep?.sleepEnd != null;
          if (healthSummary.hasData && !hasSleep) {
            return const Padding(
              padding: EdgeInsets.only(top: 22),
              child: _NoRecordedWake(),
            );
          }
          return const SizedBox.shrink();
        }

        final p = context.palette;
        final spoke = contextEngine.briefWasSpoken;
        final problem = voiceOut.problem;

        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: VoltraCard(
            title: 'This morning',
            icon: Icons.wb_twilight,
            trailing: Row(
              children: [
                if (voiceOut.status == VoiceStatus.speaking)
                  StatusChip(label: 'SPEAKING', color: p.accent)
                else if (spoke)
                  StatusChip(label: 'SAID OUT LOUD', color: p.positive)
                else
                  StatusChip(label: 'ON SCREEN ONLY', color: p.textMuted),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: voiceOut.willSpeak
                      ? 'Say this again'
                      : 'VOLTRA has no usable voice on this machine',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      voiceOut.willSpeak &&
                          voiceOut.status != VoiceStatus.speaking
                      ? contextEngine.replayBriefing
                      : null,
                  icon: Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: voiceOut.willSpeak ? p.accent : p.textMuted,
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (problem != null)
                  NoticeBox(
                    icon: Icons.volume_off_outlined,
                    color: p.warning,
                    text: problem,
                  ),
                Text(
                  brief.opening,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (brief.details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final line in brief.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        line,
                        style: TextStyle(
                          color: p.textSecondary,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                Text(
                  _footnote(brief),
                  style: TextStyle(color: p.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Where the wake time came from, and — when it applies — why the greeting
  /// arrived late. Both facts, plainly, so nothing looks like a glitch.
  static String _footnote(MorningBrief brief) {
    final woke =
        'You woke at ${formatClock(brief.wakeAt)}, '
        'from your recorded sleep';

    if (!brief.isLate) return '$woke.';

    final late = brief.lateBy;
    final howLate = late.inHours >= 1
        ? '${late.inHours} h ${late.inMinutes % 60} min'
        : '${late.inMinutes} min';

    return '$woke. VOLTRA was not open then, so this is the first chance it '
        'had to say it — $howLate later.';
  }
}

/// Shown when the export has data but no night in it.
///
/// The honest version of "no greeting today": the wake time is genuinely
/// unknown, so VOLTRA says that instead of greeting Ali at a time it made up.
class _NoRecordedWake extends StatelessWidget {
  const _NoRecordedWake();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return VoltraCard(
      title: 'This morning',
      icon: Icons.wb_twilight,
      trailing: StatusChip(label: 'NO WAKE RECORDED', color: p.textMuted),
      child: Text(
        'There is no sleep record in this export, so VOLTRA does not know when '
        'you woke up — and it will not guess. The morning briefing arrives on '
        'its own once a night has been exported from your Apple Watch.',
        style: TextStyle(color: p.textSecondary, fontSize: 13.5, height: 1.55),
      ),
    );
  }
}
