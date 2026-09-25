import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/voltra_services.dart';
import 'core/theme/voltra_theme.dart';

// NOTE: `dart:io` and `package:health` are deliberately NOT imported here, and
// nothing in lib/ outside lib/vitals/ imports `dart:html` either. The app must
// build for Windows desktop and for the web from the same sources; the
// platform-specific health access lives behind the conditional imports in
// lib/vitals/.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await desktopLink.load();
  await scheduleStore.load();

  // Not awaited: probing the Windows speech voices costs a second or two and
  // the first frame should not wait for it. Anything about to speak awaits
  // voiceOut.ensureInitialized() itself, so nothing is delivered silently.
  voiceOut.ensureInitialized();

  await contextEngine.load();

  runApp(const VoltraApp());
}

/// Root widget. Its only job is to rebuild the theme when the context changes
/// and to hand control to [AppShell].
class VoltraApp extends StatelessWidget {
  const VoltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: contextEngine,
      builder: (context, _) {
        final palette = VoltraPalette.forContext(contextEngine.snapshot);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'VOLTRA',
          theme: VoltraTheme.build(palette),
          // Morning Mode arriving is a change of light, not a page reload.
          // MaterialApp cross-fades the whole theme — including the palette,
          // which knows how to interpolate itself — so the app warms up into
          // the morning instead of snapping into it.
          themeAnimationDuration: const Duration(milliseconds: 900),
          themeAnimationCurve: Curves.easeInOutCubic,
          home: const AppShell(),
        );
      },
    );
  }
}
