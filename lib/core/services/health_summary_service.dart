import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/health_series.dart';
import '../models/health_summary.dart';
import '../networking/health_api.dart';

export '../models/health_series.dart';
export '../models/health_summary.dart';
export '../networking/health_api.dart' show HealthApi, HealthApiErrorKind;

/// Every state the health summary can be in. The UI switches on this — there
/// is no "null means error, empty means loading" guesswork.
enum HealthStatus {
  /// Never fetched in this session.
  idle,

  /// A fetch is in flight and we have nothing to show yet.
  loading,

  /// Fresh, complete data.
  ready,

  /// Real data, but some metrics are missing from the payload.
  partial,

  /// Real data, but the newest sample is older than [HealthSummary.staleAfter].
  stale,

  /// The Flask server is not reachable.
  serverOffline,

  /// The server is up but has no exported health data.
  noData,

  /// Anything else.
  error,
}

extension HealthStatusFlags on HealthStatus {
  /// True when [HealthSummaryService.summary] holds genuine Apple Watch data.
  bool get hasData =>
      this == HealthStatus.ready ||
      this == HealthStatus.partial ||
      this == HealthStatus.stale;
}

/// Owns the health summary for the whole app.
///
/// Holds exactly one source of truth. It never invents a value: on failure the
/// previous summary is kept and clearly marked, and if there was none the app
/// shows an explicit empty/offline state instead of zeros.
class HealthSummaryService extends ChangeNotifier {
  HealthSummaryService({HealthApi? api}) : _api = api ?? HealthApi();

  final HealthApi _api;

  HealthSummary? _summary;
  HealthSeries? _series;
  HealthStatus _status = HealthStatus.idle;
  String? _errorMessage;
  bool _refreshing = false;
  Timer? _poll;

  HealthSummary? get summary => _summary;

  /// Daily aggregates behind the Health and Sleep charts. Null until the
  /// first successful fetch.
  HealthSeries? get series => _series;

  HealthStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// True while a refresh runs on top of data we already have.
  bool get isRefreshing => _refreshing;

  bool get hasData => _status.hasData && _summary != null;

  String get sourceLabel => _summary?.overview.sleep?.source ?? 'Apple Watch';

  /// Poll gently. Health Auto Export pushes at most every few minutes, so
  /// anything faster is wasted work.
  static const Duration pollInterval = Duration(minutes: 2);

  /// Longest window any screen offers, fetched once and sliced locally.
  static const int seriesDays = 30;

  Future<void> refresh() async {
    if (_refreshing) return;

    _refreshing = true;
    if (_summary == null) _status = HealthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.fetchSummary();
      _summary = result;
      _errorMessage = null;

      // The series is a bonus, not a precondition. If it fails, the summary
      // still stands and the charts say they have nothing rather than the
      // whole screen falling over.
      try {
        _series = await _api.fetchSeries(days: seriesDays);
      } on Exception {
        _series = null;
      }

      if (result.isEmpty) {
        _status = HealthStatus.noData;
      } else if (result.isStale) {
        _status = HealthStatus.stale;
      } else if (result.isPartial) {
        _status = HealthStatus.partial;
      } else {
        _status = HealthStatus.ready;
      }
    } on HealthApiException catch (e) {
      _errorMessage = e.message;
      _status = switch (e.kind) {
        HealthApiErrorKind.serverOffline => HealthStatus.serverOffline,
        HealthApiErrorKind.timeout => HealthStatus.serverOffline,
        HealthApiErrorKind.noHealthData => HealthStatus.noData,
        HealthApiErrorKind.badResponse => HealthStatus.error,
      };
      // Keep the last good summary on screen, but labelled by the status above
      // so the user is never shown yesterday's numbers as if they were live.
    } catch (e) {
      _errorMessage = e.toString();
      _status = HealthStatus.error;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => refresh());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void dispose() {
    stopPolling();
    _api.dispose();
    super.dispose();
  }
}
