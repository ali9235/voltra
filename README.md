# VOLTRA

My Apple Watch has been recording my heart rate every few minutes for months. I could not look at any of it without picking up my phone, and I spend most of my day at a desktop.

Every app that solves this wants me to upload the data first. I did not want to do that. Sleep times, resting heart rate and walking patterns are a fairly precise record of where I am and what I am doing all day, and handing that to a company so I can see a chart felt like a bad trade.

So VOLTRA keeps all of it on my own machine. My iPhone posts exports to a small Flask server running on my PC over my own Wi-Fi. The desktop app reads from localhost. Nothing goes out, and there is no account to make.

---

## The rule the whole thing is built around

Most health dashboards round missing data down to zero.

If my watch did not record steps this morning, that is not "0 steps". If Health Auto Export has not run since Tuesday, yesterday's numbers are not today's. Those are different facts and showing them the same way is a lie, a small one, but the kind that makes you stop trusting the screen.

So every metric in this codebase is nullable from the JSON parser all the way to the widget. A missing value renders as `No data` with the reason next to it. The morning briefing just drops any sentence it has no measurement for. When the export goes stale the whole app says `STALE` and tells you how old the newest sample is.

It sounds like a small design choice. It is most of the work.

---

## What it does

**It knows when I actually woke up.** Not when the app launched, not when the clock hit seven. It reads the recorded `sleep_end` from my watch data. No sleep record means no wake time, and it says so instead of guessing one.

**It greets me once, out loud.** "Good morning, Ali. Hope you slept well. What would you like to do today?" Then at most three short sentences about how I slept, my resting heart rate and HRV, and what is on my schedule. Every sentence comes from a number that exists.

**The greeting cannot fire twice, and it cannot go missing.** This took more thought than the rest of the feature combined, and I explain it below.

**Morning Mode.** The app is dark the rest of the day and goes light with a sunrise gradient after a recorded wake. It follows the wake and not the clock, so waking at 13:20 still gets it.

**Eight modules** behind one sidebar: Home, Health, Sleep, Training, Schedule, Insights, Chat, Settings. They share one shell, one palette, and one health service.

---

## Three decisions I would ask about in an interview

### Why the greeting is keyed to a day and not a timestamp

My first version remembered the exact `sleep_end` instant it had greeted for. That broke within two days.

Health Auto Export revises sleep data. A later export can move last night's `sleep_end` by a minute or two as the watch finishes syncing. My app saw a new timestamp, decided it was a new wake, and said good morning at eleven in the morning for a second time.

Now it records the calendar day the sleep *ended*. A revised `sleep_end` on the same day is still the same morning. There are three rules and I wrote tests for all of them:

- It never fires twice, in one session or across a restart.
- It never fires for a previous day's wake. If I open the app on Thursday, Wednesday's greeting is gone, not queued.
- If my PC was off when I woke up, the greeting is delivered at the first launch after that wake, with a note saying how late it is.

That last one is why a simple "greet if it's morning" check does not work. I woke at 06:40 one day and did not open the app until the evening. The old code checked whether I was inside a three hour post-sleep window, found I was not, and silently threw the greeting away.

The delivery record is written to disk before the app speaks, not after. If it crashes mid-sentence I would rather lose the audio than get greeted again.

### Why it speaks English when I mostly write Arabic

There is no Arabic SAPI voice installed on this machine. Only David and Zira, both English.

The problem is what Windows does when you ask for a voice it does not have. It does not raise an error. It returns immediately and plays silence, and every return code says success. I spent an evening convinced my audio was broken.

Two things guard against it now. VOLTRA only picks from the voice list Windows actually reports, and after speaking it compares how long the call took against how long those words should take to say. A call that finishes in 40ms for a twelve second sentence gets flagged as suspect instead of counted as spoken. Either way the status shows in the top bar and in Settings.

I also decided it will not write Arabic in Latin letters to fake it. That is neither language, just noise.

### Why the server aggregates and the app does not

A week of export is around 22,000 raw samples. Sending that to Flutter and reducing it there would work and would also be slow and pointless.

The Flask service does the aggregation and returns one point per day. The app never sees a raw sample array. `/health/summary` gives today plus a seven day baseline, `/health/series?days=N` gives the daily points behind the charts.

---

## Running it

You need Flutter with Dart 3 (I built this on Flutter 3.47.5 / Dart 3.13.4) and Python 3.10+ with Flask.

```bash
git clone https://github.com/<your-username>/voltra.git
cd voltra
flutter pub get
```

On Windows:

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
