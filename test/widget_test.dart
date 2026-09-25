// VOLTRA shell smoke test.
//
// This file used to assert on the old single-page layout ("VOLTRA Desktop",
// "VITALS", "Daily Plan") and had been failing since the app became eight
// modules behind a side navigation. It now checks the shell that actually
// exists: the wordmark, all eight modules, and an honest state where health
// data would be.
//
// Note on what this test can reach: the widget test binding answers every HTTP
// request with a 400, so the health service lands in an explicit failure state.
// That is the useful thing to assert — the screen must explain itself rather
// than render zeros.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:voltra_app/app/voltra_modules.dart';
import 'package:voltra_app/core/theme/voltra_theme.dart';
import 'package:voltra_app/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the shell renders the wordmark and all eight modules', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const VoltraApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('VOLTRA'), findsWidgets);

    for (final module in VoltraModule.values) {
      expect(
        find.text(module.label),
        findsWidgets,
        reason: '${module.label} should be in the navigation',
      );
    }

    // Replacing the tree disposes AppShell, which stops the health poll timer.
    // Without this the test fails on a pending timer instead of on anything
    // real.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Home explains itself instead of showing zeros', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const VoltraApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Whatever the health link is doing, Home never invents a number: either it
    // is still reading, or it says plainly what went wrong.
    final explained = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final text = widget.data ?? '';
      return text.contains('health data') ||
          text.contains('health server') ||
          text.contains('could not read') ||
          text.contains('Reading your');
    });

    expect(explained, findsWidgets);
    expect(find.text('Ask VOLTRA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('every palette resolves to a usable theme', () {
    // Morning is a light palette and the rest are dark. Building each one
    // catches the mismatch that makes Material paint white on white.
    final palettes = <VoltraPalette>[
      VoltraPalette.morning,
      VoltraPalette.day,
      VoltraPalette.evening,
      VoltraPalette.night,
      VoltraPalette.workout,
      VoltraPalette.recovery,
    ];

    for (final palette in palettes) {
      final theme = VoltraTheme.build(palette);

      expect(
        theme.brightness,
        palette.brightness,
        reason: '${palette.name} must build a theme of its own brightness',
      );
      expect(theme.extension<VoltraPalette>(), same(palette));
      expect(theme.colorScheme.onSurface, palette.textPrimary);
    }
  });
}
