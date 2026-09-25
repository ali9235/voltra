import 'package:flutter/material.dart';

import '../../app/voltra_services.dart';
import '../../core/theme/voltra_theme.dart';
import '../../core/widgets/health_state_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/voltra_card.dart';
import 'insight_builder.dart';

/// Observations about Ali's own data, compared with Ali's own baseline.
///
/// No diagnoses, no advice dressed as medicine. Every line here is anchored
/// to a number that exists in the export, and observations that need a
/// baseline are withheld until there are enough days to form one.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: healthSummary,
      builder: (context, _) {
        final p = context.palette;

        if (!healthSummary.hasData) {
          return Padding(
            padding: const EdgeInsets.all(26),
            child: HealthStatusView.placeholder(context, healthSummary),
          );
        }

        final insights = InsightBuilder.build(
          summary: healthSummary.summary,
          series: healthSummary.series,
        );

        final grouped = <String, List<Insight>>{};
        for (final insight in insights) {
          grouped.putIfAbsent(insight.source, () => []).add(insight);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
          children: [
            Text('Insights', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'What changed against your own baseline.',
              style: TextStyle(color: p.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            ...HealthStatusView.notices(context, healthSummary),
            if (insights.isEmpty)
              VoltraCard(
                child: Text(
                  'VOLTRA has not seen enough days yet to compare today with '
                  'your usual. Keep exporting from Health Auto Export and '
                  'observations will appear here.',
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              )
            else
              for (final entry in grouped.entries) ...[
                VoltraCard(
                  title: entry.key,
                  icon: switch (entry.key) {
                    'Sleep' => Icons.bedtime_outlined,
                    'Training' => Icons.fitness_center_outlined,
                    _ => Icons.favorite_outline,
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final insight in entry.value)
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
                ),
                const SizedBox(height: 18),
              ],
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'These are observations about your own recorded data, not '
                'medical advice or a diagnosis.',
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
            HealthStatusView.sourceFooter(context, healthSummary),
          ],
        );
      },
    );
  }
}
