import 'package:flutter/material.dart';

import '../health_format.dart';
import '../theme/voltra_theme.dart';

/// One headline number with its label and a short line of context.
///
/// This is the shape every metric in VOLTRA takes. There is no view anywhere
/// that lists individual samples — the server aggregates, and this tile shows
/// the result as a number a person can read at a glance.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.context1,
    this.context2,
    this.width = 168,
    this.emphasis = false,

    /// Explains WHY there is no value. Shown only when [value] is NO DATA.
    this.missingReason,
  });

  final String label;
  final String value;
  final String? context1;
  final String? context2;
  final double width;
  final bool emphasis;
  final String? missingReason;

  bool get _missing => value == noData;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sub = _missing ? (missingReason ?? context1) : context1;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasis ? 30 : 22,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: _missing ? p.textMuted : p.textPrimary,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 5),
            Text(sub, style: TextStyle(color: p.textSecondary, fontSize: 11.5)),
          ],
          if (context2 != null && !_missing) ...[
            const SizedBox(height: 2),
            Text(context2!, style: TextStyle(color: p.textMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// A responsive grid of [MetricTile]s.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.tiles, this.spacing = 22});

  final List<Widget> tiles;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: spacing, runSpacing: spacing, children: tiles);
  }
}

/// A plain label/value line, for facts that do not deserve a headline number.
class FactRow extends StatelessWidget {
  const FactRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: p.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(
              color:
                  valueColor ?? (value == noData ? p.textMuted : p.textPrimary),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A readable sentence drawn from the data — the "insight" voice used across
/// Home, Health, Sleep and Insights.
class ReadingLine extends StatelessWidget {
  const ReadingLine(this.text, {super.key, this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: tone ?? p.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
