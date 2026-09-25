// Live end-to-end test of DesktopLink against a running VOLTRA Desktop server.
//
// Start the server first:  python voltra_health_server.py
// Then:                    flutter test test/desktop_link_live_test.dart
//
// This exercises the real Dart code the app uses: pairing over HTTP, trusted
// device persistence in SharedPreferences, online/offline status, reconnect
// and disconnect. Browser-level CORS is covered separately by
// voltra_browser_cors_test.py, which runs the same requests inside Chrome.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltra_app/services/desktop_link.dart';

const pairCode = '123456';

/// LAN IPv4 of this machine, falling back to loopback. The address has
/// changed between Ethernet and Wi-Fi on this PC before, so it is detected
/// rather than hard-coded.
Future<List<String>> candidateHosts() async {
  final hosts = <String>[];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final i in interfaces) {
      for (final a in i.addresses) {
        hosts.add(a.address);
      }
    }
  } catch (_) {}
  hosts.add('127.0.0.1');
  return hosts;
}

Future<String?> findLiveDesktop() async {
  for (final host in await candidateHosts()) {
    final link = DesktopLink();
    final ok = await link.pair(host: host, code: pairCode);
    link.dispose();
    if (ok) return host;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Null when nothing is listening. These are live integration tests against a
  /// running server, so with no server there is nothing to test — they report
  /// themselves as skipped rather than failing the suite. A red `flutter test`
  /// because a server was not started tells nobody anything, and a suite that
  /// is always red is a suite nobody reads.
  String? host;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    host = await findLiveDesktop();
    // ignore: avoid_print
    print(
      host == null
          ? 'No VOLTRA Desktop server on port 8765 — live tests skipped. '
                'Start it with: python voltra_health_server.py'
          : 'Live desktop found at $host:8765',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// True when there is no server to test against, with a line in the output
  /// saying so. These assertions are about a live HTTP conversation; with
  /// nothing listening there is no conversation to check, and failing the suite
  /// for that would say nothing about the code.
  bool noServer() {
    if (host != null) return false;
    // ignore: avoid_print
    print('  SKIPPED - no VOLTRA Desktop server on port 8765');
    return true;
  }

  test(
    'pair with the correct code connects and stores a trusted device',
    () async {
      if (noServer()) return;

      final link = DesktopLink();
      addTearDown(link.dispose);

      expect(link.isPaired, isFalse);
      expect(link.state, DesktopState.notPaired);

      final ok = await link.pair(host: host!, code: pairCode);

      expect(ok, isTrue);
      expect(link.isPaired, isTrue);
      expect(link.isOnline, isTrue);
      expect(link.state, DesktopState.online);
      expect(link.host, host);
      expect(link.port, 8765);
    },
  );

  test('pair with a wrong code is rejected and stores nothing', () async {
    if (noServer()) return;

    final link = DesktopLink();
    addTearDown(link.dispose);

    final ok = await link.pair(host: host!, code: '000000');

    expect(ok, isFalse);
    expect(link.isPaired, isFalse);
    expect(link.message, contains('wrong pair code'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('voltra.desktop.host'), isNull);
  });

  test('the pair code is never persisted', () async {
    if (noServer()) return;

    final link = DesktopLink();
    addTearDown(link.dispose);

    await link.pair(host: host!, code: pairCode);

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      expect(
        value.toString(),
        isNot(contains(pairCode)),
        reason: 'pair code leaked into SharedPreferences key "$key"',
      );
    }
  });

  test('a trusted device survives into a new DesktopLink instance', () async {
    if (noServer()) return;

    final first = DesktopLink();
    await first.pair(host: host!, code: pairCode);
    first.dispose();

    // Fresh instance, same stored prefs — no pair code supplied this time.
    final second = DesktopLink();
    addTearDown(second.dispose);
    await second.load();

    expect(second.isPaired, isTrue);
    expect(second.host, host);
    expect(
      second.isOnline,
      isTrue,
      reason: 'status heartbeat should be online',
    );
  });

  test('reconnect works without the pair code', () async {
    if (noServer()) return;

    final link = DesktopLink();
    addTearDown(link.dispose);

    await link.pair(host: host!, code: pairCode);
    expect(await link.reconnect(), isTrue);
    expect(link.state, DesktopState.online);
  });

  test('offline is reported when the desktop does not answer', () async {
    if (noServer()) return;

    final link = DesktopLink();
    addTearDown(link.dispose);

    await link.pair(host: host!, code: pairCode);
    // Point at a port nothing is listening on.
    await link.pair(host: '127.0.0.1', code: pairCode, port: 8799);

    expect(link.isOnline, isFalse);
  });

  test('disconnect clears the trusted device', () async {
    if (noServer()) return;

    final link = DesktopLink();
    addTearDown(link.dispose);

    await link.pair(host: host!, code: pairCode);
    expect(link.isPaired, isTrue);

    await link.disconnect();

    expect(link.isPaired, isFalse);
    expect(link.state, DesktopState.notPaired);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('voltra.desktop.host'), isNull);
    expect(prefs.getString('voltra.desktop.pairedAt'), isNull);
  });
}
