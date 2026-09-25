import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Connection state of the VOLTRA Desktop link.
enum DesktopState {
  /// No trusted desktop stored yet.
  notPaired,

  /// Trusted desktop stored, reachability not checked yet.
  unknown,

  /// A request is in flight.
  busy,

  /// Trusted desktop stored and /status answered online.
  online,

  /// Trusted desktop stored but unreachable right now.
  offline,
}

/// Owns pairing with VOLTRA Desktop, trusted-device persistence and the
/// online/offline heartbeat.
///
/// SECURITY NOTE: only NON-SECRET metadata is persisted (host, port, device
/// name, last-seen timestamp). The pair code is never written to
/// SharedPreferences — SharedPreferences is plaintext on disk and in
/// localStorage on Web. A real session token belongs in secure storage /
/// the encrypted VOLTRA MESH layer, which is not built yet.
class DesktopLink extends ChangeNotifier {
  static const _kHost = 'voltra.desktop.host';
  static const _kPort = 'voltra.desktop.port';
  static const _kName = 'voltra.desktop.name';
  static const _kPairedAt = 'voltra.desktop.pairedAt';
  static const _kLastSeen = 'voltra.desktop.lastSeenAt';

  static const int defaultPort = 8765;
  static const Duration _timeout = Duration(seconds: 4);
  static const Duration heartbeatInterval = Duration(seconds: 15);

  String? _host;
  int _port = defaultPort;
  String? _deviceName;
  DateTime? _pairedAt;
  DateTime? _lastSeenAt;

  DesktopState _state = DesktopState.notPaired;
  String _message = 'Not paired';
  Timer? _heartbeat;

  String? get host => _host;
  int get port => _port;
  String? get deviceName => _deviceName;
  DateTime? get pairedAt => _pairedAt;
  DateTime? get lastSeenAt => _lastSeenAt;
  DesktopState get state => _state;
  String get message => _message;
  bool get isPaired => _host != null && _host!.isNotEmpty;
  bool get isOnline => _state == DesktopState.online;

  String get baseUrl => 'http://$_host:$_port';

  /// Short line for the Home screen tile.
  String get summary {
    if (!isPaired) return 'Not paired';
    return switch (_state) {
      DesktopState.online => 'Online • $_host',
      DesktopState.offline => 'Offline • $_host',
      DesktopState.busy => 'Checking… • $_host',
      _ => 'Trusted • $_host',
    };
  }

  // ---------------------------------------------------------------- lifecycle

  /// Load the trusted desktop from disk, then probe it once.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_kHost);
    _port = prefs.getInt(_kPort) ?? defaultPort;
    _deviceName = prefs.getString(_kName);

    final pairedRaw = prefs.getString(_kPairedAt);
    _pairedAt = pairedRaw == null ? null : DateTime.tryParse(pairedRaw);
    final seenRaw = prefs.getString(_kLastSeen);
    _lastSeenAt = seenRaw == null ? null : DateTime.tryParse(seenRaw);

    if (isPaired) {
      _set(DesktopState.unknown, 'Trusted desktop: $_host');
      await refreshStatus();
      startHeartbeat();
    } else {
      _set(DesktopState.notPaired, 'Not paired');
    }
  }

  void startHeartbeat() {
    _heartbeat?.cancel();
    if (!isPaired) return;
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => refreshStatus());
  }

  void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  @override
  void dispose() {
    stopHeartbeat();
    super.dispose();
  }

  // ------------------------------------------------------------------ actions

  /// GET /status on the trusted desktop. Updates online/offline.
  Future<bool> refreshStatus() async {
    if (!isPaired) {
      _set(DesktopState.notPaired, 'Not paired');
      return false;
    }
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(_timeout);

      if (res.statusCode != 200) {
        _set(DesktopState.offline, 'Desktop answered HTTP ${res.statusCode}');
        return false;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final online = body['online'] == true;
      final name = body['name'] as String?;
      if (name != null && name.isNotEmpty) _deviceName = name;

      if (online) {
        _lastSeenAt = DateTime.now();
        await _persistLastSeen();
        _set(DesktopState.online, '${_deviceName ?? "VOLTRA Desktop"} online');
        return true;
      }

      _set(DesktopState.offline, 'Desktop reported offline');
      return false;
    } catch (e) {
      _set(DesktopState.offline, 'Desktop unreachable ($_host:$_port)');
      return false;
    }
  }

  /// POST /pair. On HTTP 200 the desktop becomes a trusted device.
  ///
  /// [code] is used for this request only and is never persisted.
  Future<bool> pair({
    required String host,
    required String code,
    int port = defaultPort,
  }) async {
    final cleanHost = host.trim();
    final cleanCode = code.trim();

    if (cleanHost.isEmpty) {
      _set(DesktopState.notPaired, 'Enter the desktop IP address');
      return false;
    }
    if (cleanCode.isEmpty) {
      _set(DesktopState.notPaired, 'Enter the pair code');
      return false;
    }

    _set(DesktopState.busy, 'Pairing with $cleanHost…');

    try {
      final res = await http
          .post(
            Uri.parse('http://$cleanHost:$port/pair'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': cleanCode,
              'device': 'VOLTRA Companion',
              'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _host = cleanHost;
        _port = port;
        _deviceName = (body['device'] as String?) ?? 'VOLTRA Desktop';
        _pairedAt = DateTime.now();
        _lastSeenAt = _pairedAt;
        await _persistTrustedDevice();
        _set(DesktopState.online, 'Connected to $_deviceName');
        startHeartbeat();
        return true;
      }

      if (res.statusCode == 401) {
        _set(DesktopState.notPaired, 'Pairing failed — wrong pair code');
      } else {
        _set(DesktopState.notPaired, 'Pairing failed — HTTP ${res.statusCode}');
      }
      return false;
    } on TimeoutException {
      _set(DesktopState.notPaired, 'Desktop did not answer ($cleanHost:$port)');
      return false;
    } catch (e) {
      _set(
        DesktopState.notPaired,
        'Desktop unreachable ($cleanHost:$port). '
        'Check the IP, the firewall, and that the server is running.',
      );
      return false;
    }
  }

  /// Re-probe the stored trusted desktop without asking for the code again.
  Future<bool> reconnect() async {
    if (!isPaired) {
      _set(DesktopState.notPaired, 'No trusted desktop stored');
      return false;
    }
    _set(DesktopState.busy, 'Reconnecting to $_host…');
    final ok = await refreshStatus();
    if (ok) startHeartbeat();
    return ok;
  }

  /// Forget the trusted desktop and wipe its stored metadata.
  Future<void> disconnect() async {
    stopHeartbeat();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHost);
    await prefs.remove(_kPort);
    await prefs.remove(_kName);
    await prefs.remove(_kPairedAt);
    await prefs.remove(_kLastSeen);

    _host = null;
    _port = defaultPort;
    _deviceName = null;
    _pairedAt = null;
    _lastSeenAt = null;
    _set(DesktopState.notPaired, 'Disconnected — trusted device removed');
  }

  // ------------------------------------------------------------------ private

  Future<void> _persistTrustedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    // NON-SECRET metadata only. The pair code is intentionally not stored.
    await prefs.setString(_kHost, _host!);
    await prefs.setInt(_kPort, _port);
    if (_deviceName != null) await prefs.setString(_kName, _deviceName!);
    await prefs.setString(_kPairedAt, _pairedAt!.toIso8601String());
    await prefs.setString(_kLastSeen, _lastSeenAt!.toIso8601String());
  }

  Future<void> _persistLastSeen() async {
    if (!isPaired || _lastSeenAt == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSeen, _lastSeenAt!.toIso8601String());
  }

  void _set(DesktopState state, String message) {
    _state = state;
    _message = message;
    notifyListeners();
  }
}
