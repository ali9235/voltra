import 'package:flutter/material.dart';

import '../models/health_series.dart';
import '../theme/voltra_theme.dart';

/// The Today / 7 Days / 30 Days selector.
enum HealthRange { today, week, month }

extension HealthRangeInfo on HealthRange {
  String get label => switch (this) {
    HealthRange.today => 'Today',
    HealthRange.week => '7 Days',
    HealthRange.month => '30 Days',
  };

  int get days => switch (this) {
    HealthRange.today => 1,
    HealthRange.week => 7,
    HealthRange.month => 30,
  };
}

class RangeSelector extends StatelessWidget {
  const RangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HealthRange value;
  final ValueChanged<HealthRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final range in HealthRange.values)
            GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: range == value
                      ? p.accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: range == value ? p.accent : p.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A compact daily trend. One bar per day — never one bar per sample.
///
/// Draws nothing but the days that exist. A gap in the export is a gap in the
/// chart, not a zero.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.series,
    this.height = 120,
    this.formatValue,
    this.highlightLast = true,
  });

  final MetricSeries series;
  final double height;
  final String Function(double value)? formatValue;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final points = series.points.where((e) => e.value != null).toList();

    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No days with data in this window',
            style: TextStyle(color: p.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final values = points.map((e) => e.value!).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final average = values.reduce((a, b) => a + b) / values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              values: values,
              maxValue: maxValue,
              minValue: minValue,
              average: average,
              barColor: p.accent,
              mutedColor: p.textMuted,
              averageColor: p.border,
              highlightLast: highlightLast,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _dayLabel(points.first.day),
              style: TextStyle(color: p.textMuted, fontSize: 10.5),
            ),
            const Spacer(),
            Text(
              'avg ${_fmt(average)}',
              style: TextStyle(color: p.textMuted, fontSize: 10.5),
            ),
            const Spacer(),
            Text(
              _dayLabel(points.last.day),
              style: TextStyle(color: p.textMuted, fontSize: 10.5),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(double v) =>
      formatValue != null ? formatValue!(v) : v.toStringAsFixed(0);

  static String _dayLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.maxValue,
    required this.minValue,
    required this.average,
    required this.barColor,
    required this.mutedColor,
    required this.averageColor,
    required this.highlightLast,
  });

  final List<double> values;
  final double maxValue;
  final double minValue;
  final double average;
  final Color barColor;
  final Color mutedColor;
  final Color averageColor;
  final bool highlightLast;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // Baseline at zero for totals, slightly below the minimum for averages
    // that never approach zero (resting HR, HRV) so the shape stays readable.
    final base = minValue > 0 && minValue / maxValue > 0.55
        ? minValue - (maxValue - minValue) * 0.6
        : 0.0;
    final span = (maxValue - base).abs() < 0.0001 ? 1.0 : maxValue - base;

    final count = values.length;
    final slot = size.width / count;
    final barWidth = (slot * 0.56).clamp(3.0, 26.0);

    final avgPaint = Paint()
      ..color = averageColor
      ..strokeWidth = 1;
    final avgY = size.height - ((average - base) / span) * size.height;
    canvas.drawLine(Offset(0, avgY), Offset(size.width, avgY), avgPaint);

    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final paint = Paint()
        ..color = (highlightLast && isLast)
            ? barColor
            : barColor.withValues(alpha: 0.32);

      final normalized = ((values[i] - base) / span).clamp(0.0, 1.0);
      final barHeight = (normalized * size.height).clamp(2.0, size.height);
      final left = slot * i + (slot - barWidth) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values ||
      old.barColor != barColor ||
      old.highlightLast != highlightLast;
}
