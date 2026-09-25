# Feature status

This is the honest version. I checked each item against the code rather than against what I remember writing, and where something is half done I have written what is missing rather than calling it done.

Three states:

- **Done** — works end to end with real data.
- **Partial** — some of it works. The gap is named.
- **Not built** — no code exists for it. Not started, not broken.

Counts as of the last commit: 8 done, 8 partial, 9 not built.

---

## Done

### Morning greeting
Speaks once after a recorded wake, then shows the same words on the Home card. Delivery is keyed to the calendar day the sleep ended, so it cannot repeat and cannot fire for yesterday. A greeting missed because the PC was off is delivered at the next launch with a note saying how late it is.

`lib/core/context_engine/context_engine.dart` — wake detection and delivery
`lib/core/context_engine/morning_brief.dart` — the wording
`lib/features/home/home_screen.dart` — the card

### Smart context
`MORNING`, `DAY`, `EVENING`, `NIGHT` from the clock. `POST_SLEEP` and `REST_DAY` from the real sleep-end time. The palette and the Home content both follow it.

`lib/core/context_engine/context_engine.dart`
`lib/core/context_engine/context_state.dart`
`lib/core/theme/voltra_palette.dart` — which palette each state gets

### Health dashboard
Heart rate, resting HR, HRV, sleep, steps, active energy and distance, each with a seven day baseline. Missing metrics render `No data` with a reason.

`lib/features/health/health_screen.dart`
`lib/features/home/home_screen.dart` — the Today card
`lib/core/models/health_summary.dart` — the typed model
`lib/core/widgets/metric_tile.dart` — how one metric is drawn

### Sleep insights
Duration, seven day average, bedtime and wake time, and a stale-data warning when the newest sample is more than six hours old.

`lib/features/sleep/sleep_screen.dart`
`lib/core/models/health_summary.dart` — `SleepSummary`, `staleAfter`
`lib/core/widgets/health_state_view.dart` — the stale and partial notices

### Dynamic themes
Six palettes that change with time of day and activity. Morning is a light palette with a sunrise gradient, cross-faded by `MaterialApp`.

`lib/core/theme/voltra_palette.dart` — the colours
`lib/core/theme/voltra_theme.dart` — palette to `ThemeData`
`lib/main.dart` — the cross-fade timing

### Automatic health refresh
Polls every two minutes, and shows how old the newest sample is rather than when it last polled. The distinction matters: a successful poll of stale data is still stale.

`lib/core/services/health_summary_service.dart` — `pollInterval`, `refresh()`
`lib/core/widgets/health_state_view.dart` — the freshness line

### Human-readable data
`78 bpm`, `7h 25m`, `3 d ago`. One formatting module, and no raw JSON anywhere in the UI.

`lib/core/health_format.dart`

### No fake data
Every metric is nullable from parser to widget, and `null` formats as `No data`. This is enforced by the type system, not by discipline.

`lib/core/models/health_summary.dart`
`lib/core/health_format.dart`

---

## Partial

### Workout mode
**Works:** a rest timer with 60/90/120/180 second presets, and readiness signals from the watch.
**Missing:** today's workout, exercises, sets and reps, and a post-workout summary. There is no workout log, so the screen says so instead of showing an empty template.

`lib/features/training/training_screen.dart`

### Recovery score
**Works:** readiness signals written as sentences comparing sleep, resting HR and HRV against your own seven day baseline.
**Missing:** a single number. There is no score, because I did not want to invent a weighting I could not justify. Deciding that formula is the actual work here.

`lib/features/training/training_screen.dart` — the `_readiness` section

### Schedule
**Works:** day, week and month views, adding and editing events, and a Next Event card on Home.
**Missing:** a live countdown to the next event. The card shows the start and end time, not time remaining.

`lib/features/schedule/schedule_screen.dart`
`lib/features/schedule/schedule_store.dart`
`lib/features/home/home_screen.dart` — the Next card

### VOLTRA insights
**Works:** comparisons against your own averages, for example sleep against the seven day mean, generated from the real daily series.
**Missing:** more than a handful of rules. It is a small set of hand-written comparisons, not a general insight engine.

`lib/features/insights/insight_builder.dart` — where the rules live
`lib/features/insights/insights_screen.dart`

### AI chat
**Works:** answers "how did I sleep", "should I train today" and similar from your real exported data, and says plainly when the data cannot answer.
**Missing:** it is keyword matching, not a language model. It matches on words like `sleep`, `train`, `gym` and routes to a hand-written answer. Ask it something outside those topics and it tells you what it can answer instead.

`lib/features/chat/local_answers.dart` — the matching and the answers
`lib/features/chat/chat_screen.dart` — the UI

### Voice assistant
**Works:** speech output through Windows SAPI, with the silent-failure detection described in the README.
**Missing:** all input. There is no microphone, no speech recognition, no commands. It talks, it does not listen.

`lib/core/voice/voice_output_io.dart` — the Windows implementation
`lib/core/services/voice_service.dart` — status and the speak API

### Offline mode
**Works:** when the server is unreachable the app keeps the last good data on screen, labels it, and explains what failed. It never blanks out and never shows zeros.
**Missing:** the data is not cached to disk, so a cold start with the server down has nothing to show beyond an explanation.

`lib/core/services/health_summary_service.dart` — the status enum
`lib/core/networking/health_api.dart` — typed failure kinds
`lib/core/widgets/health_state_view.dart` — what each failure looks like

### Windows native
**Works:** it is a real Flutter Windows desktop app, not a web wrapper. The web build exists as a preview only and has no voice.
**Missing:** a shipped `.exe`. The release build needs Windows Developer Mode, which is currently off on my machine, so I have not produced a binary.

`windows/` — the runner
`!VOLTRA.bat` — the launcher
`!INSTALL_WINDOWS_BUILD.bat` — the prerequisites

---

## Not built

No code exists for any of these. I am listing them because they are on my plan, not because they are hiding somewhere.

| Feature | What it needs | Where it would go |
| --- | --- | --- |
| **VOLTRA Orb** | A painted widget reacting to listening / thinking / speaking. Voice output already exposes the state to drive it. | new `lib/core/widgets/voltra_orb.dart`, driven by `voice_service.dart` |
| **Voice commands** | Speech to text. A `VoiceInput` layer mirroring `VoiceOutput`, behind the same conditional import pattern. | new `lib/core/voice/voice_input*.dart` |
| **System tray** | A Windows tray icon and a window that hides instead of closing. Needs a package such as `tray_manager` plus `window_manager`. | `pubspec.yaml`, then `lib/main.dart` |
| **Start with Windows** | A registry entry under `CurrentVersion\Run`, or a Startup folder shortcut, with a toggle in Settings. | `lib/features/settings/settings_screen.dart` |
| **Notifications** | Local notifications for the workout reminder, morning summary and sleep reminder. Needs a package and a scheduler. | `pubspec.yaml`, then a new `lib/core/services/notification_service.dart` |
| **Quick actions** | Buttons for Start Workout / Ask VOLTRA / View Sleep / Add Event. The navigation callback they need already exists on Home. | `lib/features/home/home_screen.dart` |
| **Command palette** | Ctrl+K search across modules and actions. Needs a `Shortcuts` and `Actions` wrapper in the shell plus an overlay. | `lib/app/app_shell.dart`, plus a new palette widget |
| **Personalization** | Accent colour, card order and pinned metrics, persisted. The palette is already a `ThemeExtension`, so an accent override is the smallest of the three. | `lib/core/theme/voltra_palette.dart`, `lib/features/settings/settings_screen.dart` |
| **Trends: Today / 7 / 30** | The server already returns 30 days via `/health/series?days=N` and the chart widget exists. What is missing is the range selector and the comparison line. | `lib/features/health/health_screen.dart`, `lib/core/widgets/trend_chart.dart` |

Of those, **Quick actions** and **Trends** are the cheapest. Both are mostly wiring up things that already exist. **System tray**, **Start with Windows** and **Notifications** are the three that make it feel like a real desktop app rather than a window you open.

---

## Privacy first

Listed separately because it is not a feature so much as a constraint the rest is built under.

Health data never leaves the machine. The Flask server binds to the LAN so the iPhone can post to it, and the app reads over loopback. There is no account, no external service, no telemetry. The export file is gitignored by name and by pattern.

`voltra_health_server.py` — the origin restriction
`.gitignore` — the health data and secrets blocks
`lib/core/networking/health_api.dart` — reads `127.0.0.1` only
