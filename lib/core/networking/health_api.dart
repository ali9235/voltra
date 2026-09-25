import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/health_series.dart';
import '../models/health_summary.dart';

/// Why a fetch failed. The UI shows a different screen for each of these, so
/// they must stay distinguishable — "something went wrong" is not acceptable.
enum HealthApiErrorKind {
  /// Nothing is listening on the health port. The Flask server is not running.
  serverOffline,

  /// The server answered, but there is no health_payload.json yet — Health
  /// Auto Export has never POSTed.
  noHealthData,

  /// The server answered with an error or something unparseable.
  badResponse,

  /// The request took too long.
  timeout,
}

class HealthApiException implements Exception {
  final HealthApiErrorKind kind;
  final String message;

  const HealthApiException(this.kind, this.message);

  @override
  String toString() => message;
}

/// Read-only client for the local VOLTRA health server.
///
/// The server is bound to the LAN so the iPhone can POST to it, but this app
/// always talks to it over loopback. The health data never leaves this machine
/// and this client never writes.
class HealthApi {
  /// Loopback on purpose: the desktop app has no reason to reach the LAN
  /// address, and loopback keeps the data local by default.
  static const String defaultBaseUrl = 'http://127.0.0.1:8766';

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  HealthApi({
    this.baseUrl = defaultBaseUrl,
    this.timeout = const Duration(seconds: 6),
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri get summaryUri => Uri.parse('$baseUrl/health/summary');

  Uri seriesUri(int days) => Uri.parse('$baseUrl/health/series?days=$days');

  Future<HealthSummary> fetchSummary() async =>
      HealthSummary.fromJson(await _getJson(summaryUri));

  /// Daily aggregates for the last [days] days. The server does the
  /// collapsing; the app never sees a raw sample array.
  Future<HealthSeries> fetchSeries({int days = 30}) async =>
      HealthSeries.fromJson(await _getJson(seriesUri(days)));

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    http.Response response;

    try {
      response = await _client.get(uri).timeout(timeout);
    } on Exception catch (e) {
      final text = e.toString().toLowerCase();
      if (text.contains('timeout')) {
        throw HealthApiException(
          HealthApiErrorKind.timeout,
          'The health server at $baseUrl did not answer in time.',
        );
      }
      throw HealthApiException(
        HealthApiErrorKind.serverOffline,
        'Cannot reach the health server at $baseUrl. '
        'Run !VOLTRA.bat to start it.',
      );
    }

    if (response.statusCode == 404) {
      throw const HealthApiException(
        HealthApiErrorKind.noHealthData,
        'The server is running but has no health data yet. Run an export from '
        'Health Auto Export on the iPhone.',
      );
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Summary response was not a JSON object.');
      }
      body = decoded;
    } on Exception {
      throw HealthApiException(
        HealthApiErrorKind.badResponse,
        'The health server returned something VOLTRA could not read '
        '(HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode != 200 || body['ok'] != true) {
      throw HealthApiException(
        HealthApiErrorKind.badResponse,
        body['error']?.toString() ??
            'The health server returned HTTP ${response.statusCode}.',
      );
    }

    return body;
  }

  void dispose() => _client.close();
}
