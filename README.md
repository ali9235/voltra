# 
<div align="center">

# VOLTRA

### Intelligent Desktop & Device Ecosystem

**AI • Windows • Mobile • Embedded Systems**

An experimental intelligent system connecting desktop interaction, mobile control, and embedded hardware.

</div>

---

## Overview

VOLTRA is an evolving engineering project exploring connected intelligent interfaces.

## Project Components

- **ARVEN** — Main assistant interface
- **CODEX** — Coding and engineering agent
- **Desktop** — Windows control experience
- **Mobile** — Remote interface
- **Control Core** — ESP32-based hardware interface

## Project Status

Under active development. Features may be experimental or incomplete.

## Screenshots

Add screenshots in the assets folder and link them here.

## Roadmap

- [ ] Improve desktop stability
- [ ] Refine assistant interactions
- [ ] Improve secure device connectivity
- [ ] Document hardware integration

## License

See the repository license file, if provided.
  

```bat
!VOLTRA.bat
```

That starts the health server, waits for it to answer, and launches the app. Or run the two halves yourself:

```bash
python voltra_health_server.py     # health server on :8766
flutter run -d windows             # the app
```

For the native Windows build you need Visual Studio 2022 Build Tools with the C++ workload, and Windows Developer Mode switched on. Flutter needs Developer Mode to create symlinks for a plugin build, and it fails with a fairly unhelpful message if it is off. `!INSTALL_WINDOWS_BUILD.bat` handles both.

To connect real data, install Health Auto Export on your iPhone and add a REST API automation pointing at `http://<your-pc-lan-ip>:8766/health`, JSON, POST. The app picks it up within two minutes. Without it the app still runs and tells you honestly that nothing has been exported.

### From a clean clone, in order

If you are trying this from scratch, this is the whole sequence. Steps 1 to 4 work without any health data at all; the app will simply tell you nothing has been exported yet.

1. `git clone` the repository and `cd` into it.
2. `flutter pub get`.
3. `pip install flask`.
4. `python voltra_health_server.py`. It prints its LAN address and starts listening on port 8766. Leave it running. Visiting `http://127.0.0.1:8766/health/summary` in a browser should return JSON.
5. In another terminal, `flutter run -d windows`. First build takes a few minutes. If it fails with *"Building with plugins requires symlink support"*, Developer Mode is off; see the note above.
6. Optional, for real data: install Health Auto Export on an iPhone on the same Wi-Fi, add a REST API automation posting JSON to `http://<the address from step 4>:8766/health`, and run an export.

To see the app without Flutter's Windows toolchain, `flutter run -d chrome` works and renders everything. It has no voice, and says so in the top bar.

### Tests

```bash
dart format lib test
flutter analyze
flutter test
flutter build windows --release
```

`tools/VOLTRA_VERIFY.bat` runs all four on Windows and writes each result to `_logs/`.

33 tests pass. They are not evenly spread, deliberately: they cover the parts where being wrong would be invisible.

`test/morning_experience_test.dart` holds most of them. Three of the four things I promise about the greeting are promises that something will *not* happen, and those are exactly the kind that rot quietly. So there is a test for each: that it never fires twice in a session, that it never fires again after a restart, that it never fires for a previous day's wake, and that a greeting missed while the PC was off is still delivered later.

Testing that last one honestly meant the engine could not call `DateTime.now()` internally. If it did, the test would pass or fail depending on what time of day I happened to run it. So `ContextEngine` takes an injected clock:

```dart
ContextEngine({required this.health, this.voice, this.schedule, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
```

Production passes nothing and gets the real clock. Tests pass a fixed instant, which makes "he woke at 06:40 and opened the app at 21:15" a deterministic scenario rather than something I have to stay up to verify. The same seam lets me assert that a sleep record ending in the future is treated as bad data instead of a wake.

The rest covers the briefing wording, including that a missing metric produces no sentence and no digit anywhere in the output; the voice layer, including the case where the engine reports success but produced silence; and the palettes, checking each one builds a `ThemeData` of matching brightness, which is the mistake that makes Material paint white on white.

`test/desktop_link_live_test.dart` is an integration test against a live server. It skips itself with a printed notice when nothing is listening on port 8765, rather than failing the suite for an absent service.

---

## How it is put together

```
Apple Watch
  -> Apple Health on iPhone
    -> Health Auto Export
      -> POST http://<pc-lan-ip>:8766/health
        -> voltra_health_server.py
          -> _data/health_payload.json          (local, gitignored)
            -> GET /health/summary              today + 7 day baseline
            -> GET /health/series?days=N        one point per day
              -> VOLTRA, over loopback
```

The Flask server binds to `0.0.0.0` for one reason, which is that my phone has to reach it over the LAN. Requests are limited to loopback and private ranges. Do not forward the port.

```
lib/
  app/                shell, module registry, the shared service singletons
  core/
    context_engine/   time of day, activity state, the morning briefing
    models/           typed health models, every metric nullable
    networking/       read-only HTTP client with typed failure kinds
    services/         health state machine, voice service
    voice/            Windows SAPI behind a conditional import
    theme/            VoltraPalette as a ThemeExtension, VoltraTheme
    widgets/          cards, metric tiles, trend chart, state views
  features/           one folder per module
  vitals/             platform health provider behind a conditional import
  services/           desktop pairing client
```

State is plain `ChangeNotifier` and `ListenableBuilder`. No state management package. For an app this size the extra layer would have cost more than it saved.

Platform specific code sits behind conditional imports so the same sources build for Windows and for web without `dart:io` leaking into the web build.

There is a full feature by feature status map in [FEATURES.md](FEATURES.md), including what is not built yet.

---

## Screenshots

Put PNGs in `docs/screenshots/` with these names, then uncomment the table below.

| File | What it shows |
| --- | --- |
| `home-morning.png` | Home in Morning Mode, light palette and the briefing card |
| `home-night.png` | Home with a stale export, showing `STALE` and `No data` with reasons |
| `health.png` | Health module and seven day trends |
| `sleep.png` | Sleep module with the stage breakdown correctly withheld |
| `settings.png` | Settings, health pipeline and voice diagnostics |
| `insights.png` | Insights generated from the real series |

<!-- Uncomment once the files exist.

| Home, Morning Mode | Home, stale export |
| --- | --- |
| ![Morning](docs/screenshots/home-morning.png) | ![Night](docs/screenshots/home-night.png) |

| Health | Sleep |
| --- | --- |
| ![Health](docs/screenshots/health.png) | ![Sleep](docs/screenshots/sleep.png) |

| Settings | Insights |
| --- | --- |
| ![Settings](docs/screenshots/settings.png) | ![Insights](docs/screenshots/insights.png) |

-->

One warning before you publish any of these. The dashboard shows real heart rate, HRV and sleep values and the footer names the watch they came from. The repo is public. Your numbers do not have to be.

---

## What is not built

I would rather say this plainly than have someone find it.

**iOS and HealthKit.** `lib/vitals/` has a HealthKit provider behind a conditional import and `codemagic.yaml` describes an iOS pipeline. Neither has ever been built or run on a device. The working path on every platform today is Health Auto Export into the local Flask server, not a direct HealthKit read.

**Desktop pairing.** `lib/services/desktop_link.dart` is a client for a "VOLTRA Desktop" service on port 8765. That service is not in this repository. The pairing panel in Settings will report offline, and its integration tests skip themselves when nothing is listening. It is there because I built the client first and the server never followed.

**Sleep stages.** Deep, REM and core are modelled and gated behind the server's `stages_available` flag. My current export reports all four stages as zero, so the app declines to draw a chart of four zeros. The code is ready for a payload that has them.

**Voice input.** VOLTRA speaks. It does not listen. There is no speech recognition anywhere in the project.

**The Windows release build** does not currently produce an exe on my machine, because Developer Mode is off. `flutter analyze` is clean and all 33 tests pass, but I have not shipped a binary.

---

## Where I would take it next

The thing I want most is session tracking, so `PRE_WORKOUT`, `WORKOUT` and `POST_WORKOUT` become measured states rather than ones the engine models but never sees.

After that, separating "today" from "the newest sample". Right now the server derives its reference date from the latest data point, so a three day old export labels three day old numbers as today's. The UI marks it `STALE` so nothing is actually misleading, but the two ideas should not share a variable.

Then either build the pairing service or delete the client, widen the tests past the context engine into the feature screens, and package the Windows build so it runs without a Flutter toolchain installed.

---

## Privacy

- `_data/health_payload.json` is your export. It is gitignored and must never be committed. It contains a minute by minute record of heart rate, HRV, sleep and walking gait.
- The server stores no credentials and needs no account.
- It listens on the LAN only so your phone can reach it. Do not expose it to the internet.

---

Built by Ali Shantti.
