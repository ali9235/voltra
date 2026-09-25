import 'package:flutter/material.dart';

import '../theme/voltra_theme.dart';

/// The single card shape used everywhere in VOLTRA.
class VoltraCard extends StatelessWidget {
  const VoltraCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon case final iconData?) ...[
                  Icon(iconData, size: 18, color: p.textSecondary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Small uppercase pill used for statuses like LIVE / STALE / NO DATA.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

/// A short coloured explanation. Used for stale data, partial exports and
/// failed refreshes — never for decoration.
class NoticeBox extends StatelessWidget {
  const NoticeBox({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title used between cards on a long screen.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
