import 'package:flutter/material.dart';

import '../health_format.dart';
import '../services/health_summary_service.dart';
import '../theme/voltra_theme.dart';
import 'voltra_card.dart';

/// The one place that turns a [HealthStatus] into words.
///
/// Every module uses it, so "server offline" reads identically on Home,
/// Health, Sleep and Insights — and no module ever silently renders zeros.
class HealthStatusView {
  const HealthStatusView._();

  static (Color, String) chip(BuildContext context, HealthStatus status) {
    final p = context.palette;
    return switch (status) {
      HealthStatus.ready => (p.positive, 'LIVE'),
      HealthStatus.partial => (p.accent, 'PARTIAL'),
      HealthStatus.stale => (p.warning, 'STALE'),
      HealthStatus.loading => (p.textMuted, 'LOADING'),
      HealthStatus.idle => (p.textMuted, 'IDLE'),
      HealthStatus.serverOffline => (p.danger, 'SERVER OFFLINE'),
      HealthStatus.noData => (p.warning, 'NO DATA'),
      HealthStatus.error => (p.danger, 'ERROR'),
    };
  }

  /// Notices shown above real data — stale export, partial export, or a
  /// refresh that failed while older data is still on screen.
  static List<Widget> notices(
    BuildContext context,
    HealthSummaryService service,
  ) {
    final p = context.palette;
    final summary = service.summary;
    final out = <Widget>[];

    if (service.status == HealthStatus.stale && summary != null) {
      out.add(
        NoticeBox(
          icon: Icons.schedule,
          color: p.warning,
          text:
              'The newest sample is ${formatAge(summary.dataAge)}. '
              'Run an export from Health Auto Export on your iPhone to bring '
              'this up to date.',
        ),
      );
    }

    if (service.status == HealthStatus.partial && summary != null) {
      out.add(
        NoticeBox(
          icon: Icons.info_outline,
          color: p.accent,
          text:
              'This export is missing: '
              '${summary.overview.missingMetrics.join(", ")}.',
        ),
      );
    }

    if ((service.status == HealthStatus.serverOffline ||
            service.status == HealthStatus.error) &&
        summary != null) {
      out.add(
        NoticeBox(
          icon: Icons.cloud_off,
          color: p.danger,
          text:
              '${service.errorMessage ?? "The last refresh failed."} '
              'These numbers are the last ones VOLTRA received.',
        ),
      );
    }

    return out;
  }

  /// Full-panel message for when there is no data at all to show.
  static Widget placeholder(
    BuildContext context,
    HealthSummaryService service,
  ) {
    final p = context.palette;

    final (icon, color, title, detail) = switch (service.status) {
      HealthStatus.idle || HealthStatus.loading => (
        Icons.hourglass_empty,
        p.textSecondary,
        'Reading your health data…',
        'VOLTRA is asking the local health server for your latest summary.',
      ),
      HealthStatus.serverOffline => (
        Icons.cloud_off,
        p.danger,
        'The health server is not running',
        service.errorMessage ??
            'Start VOLTRA with !VOLTRA.bat — it launches the health server '
                'on port 8766 before opening the app.',
      ),
      HealthStatus.noData => (
        Icons.inbox_outlined,
        p.warning,
        'No health data has been exported yet',
        'The server is running but has received nothing. Open Health Auto '
            'Export on your iPhone and run an export over Wi-Fi.',
      ),
      _ => (
        Icons.error_outline,
        p.danger,
        'VOLTRA could not read your health data',
        service.errorMessage ?? 'Unknown error.',
      ),
    };

    return VoltraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The "Ali's Apple Watch · last sample 1 h ago" footer.
  static Widget sourceFooter(
    BuildContext context,
    HealthSummaryService service,
  ) {
    final p = context.palette;
    final summary = service.summary;
    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        '${service.sourceLabel} · last sample ${formatAge(summary.dataAge)}',
        style: TextStyle(color: p.textMuted, fontSize: 11),
      ),
    );
  }
}
