# Contributing

Everything needed to work on Sands or take over the project.

## Contents

- [Development setup](#development-setup)
- [Architecture](#architecture)
- [Project layout](#project-layout)
- [Tests](#tests)
- [Offscreen previews and bench](#offscreen-previews-and-bench)
- [Performance rules](#performance-rules)
- [Conventions](#conventions)
- [Releasing a version](#releasing-a-version)

## Development setup

1. Clone the repository into the DMS plugin folder and enable it in **Settings → Plugins**:

   ```sh
   git clone https://github.com/lung595/Sands ~/.config/dms/plugins/smartTimer
   ```

2. Add the **Sands** widget to the bar to see the pill and the panel.
3. DMS reloads QML on save, but Qt keeps `components/` and `.js` files cached in the running shell: **run `dms restart`** after changing them.

Tools: `gjs` (tests), `qmllint` from Qt 6 and `python3` (lint).

## Architecture

`plugin.json` declares a **composite** plugin with the id `smartTimer` (used by the IPC target, the settings and the saved state; do not rename it, or users lose their data):

| Component | File | Role |
| --- | --- | --- |
| Daemon | `TimerDaemon.qml` | The engine, one instance: the timer list, its actions and the clock. Delegates to `components/daemon/` |
| Widget | `TimerWidget.qml` | Host wiring only: visibility, click and IPC hooks, the pill and the panel. Only displays the daemon's state and forwards actions |
| Launcher | `TimerLauncher.qml` | Launcher provider: answers only when the input looks like a duration |
| Settings | `TimerSettings.qml` | Settings page |

The widget and the launcher reach the engine through `PluginService.pluginDaemonInstances["smartTimer"]`.

The daemon is split by role, one file each, in `components/daemon/`. Each QML file only wires; its rules are in the `.js` next to it:

| File | Role | Pure logic |
| --- | --- | --- |
| `TimerStore.qml` | Persistence through the DMS plugin state; drops the settings an older Sands left | `Retired.js` |
| `AlarmSound.qml` | Every sound: alarm, settings preview, tick (one idle `Process` each) | `Sound.js` |
| `TimerNotifier.qml` | End notification with Stop / +5 min (one `notify-send` per ringing timer) | `Notifications.js` |
| `TimerIpc.qml` | The `dms ipc call smartTimer …` commands | `IpcReplies.js` |
| `ReportService.qml` | The anonymous report, built only when asked (settings button or `diagnostics` IPC call) | `diagnostics/*.js` |
| `ReportClipboard.qml` | Copies the report: `wl-copy --sensitive`, then `dms clipboard copy`; the text goes through standard input | `diagnostics/Gather.js` |
| `ToolProcess.qml` | A `Process` that always ends with one `finished`, even when the tool is missing or hangs | |
| | State transitions, expiry, next wake-up, restore | `Lifecycle.js` |

Logic that can be tested lives in **pure `.js` files** with no QML:

- `TimeParser.js`: natural-language parser (English and French) and formatting. `parse()` runs the named stages of `STAGES` in order (typos, context verb, keyword, repeat, clock time, `1:30`, fractions, phrases, number + unit, bare numbers, approximations); each consumes what it read and what is left is the label. Its words come from the language packs `lang/en.js` and `lang/fr.js` (`PACKS`): `grammar(packs)` builds every regex from their union, once. A new language is one more pack of the same shape, added to `PACKS`; `tests/parser.test.js` checks that every pack has the keys of the English one and runs its cases with each pack alone and with the union.
- `Commands.js`: the launcher commands on running timers (« timer +5 », « timer -2 pâtes », « pause pâtes », « reprendre », « snooze 10 », « renomme pâtes en riz », « rename tea to infusion », « thé = infusion »). Not wired yet; the launcher will call, on each keystroke and before `TP.parse`:
  - `parseCommand(text, { now })` → `{ kind, delta, name, newName, minutes, lang }` or null. `kind` is `adjust` (`delta` in signed ms), `pause`, `resume`, `snooze` (`minutes`, 0 = the default), `rename` (`newName`, emoji removed); `name` "" means the nearest timer; `lang` is `fr` / `en` when the verb belongs to one language only.
  - `resolveTarget(intent, daemon.timers, now)` → the timer, or null. No name: the nearest the command applies to (ringing first, then the one ending first, `Lifecycle.sortTimers`); a name: that one (whole name, then its start, then a part; accents, case and emoji ignored).
  - `previewCommand(intent, target, now, { lang, use24, snoozeMinutes })` → `{ text, icon, at, changed }`: « +5 min à Pâtes (finit à 18:47) » / « +5 min to Pasta (ends 18:47) », a Material Symbols icon name, the new end, and `changed: false` when Enter would do nothing. The 10 s floor and the restart of a ringing timer come from `Lifecycle.adjust` on a copy, so the line shows what Enter will do.
  - A null intent or target means "not a command": fall back to `TP.parse`, so « pause café 15 min » or « pasta 12 » still start a timer. On Enter, call the daemon with `target.id`: `adjust(id, delta)`, `pause(id)`, `resume(id)`, `rename(id, newName)`, and for a snooze `adjust(id, minutes * 60000)` as `TimerIpc.snooze` does.
- `Timers.js`: pure timer logic (time left, progress, names, recents ranking, colour slots) that `TimerDaemon.qml` calls with its clock.
- `components/daemon/*.js`: the rules of the daemon's parts (see the table above). They import `TimeParser.js` and `Timers.js` where needed.
- `components/alert/*.js`: the visual alert of a finished timer, `AlertPolicy.js` (which alert and when, read by `DuneAlert.qml` and the settings), `HaloMotion.js` (the Edge halo steps), `DuneMotion.js` and `DuneStyles.js` (the Rising dune), `SandTint.js` (the sand colours).
- `Preview.js`: the one-line preview and the « Rings at … » line the launcher shows before Enter.
- `Guide.js`: the short notes shown when something can't be done (title, hint, guide anchor); a test checks every anchor exists in `docs/GUIDE.md`.
- `components/Motion.js`: every looping motion as a pure function of time.
- `components/Press.js`: what the controls drawn by hand share (the keys that press them, the 44 px target, the fades).
- `diagnostics/*.js`: the anonymous report. `Gather.js` (the probes and how their answers are read), `Redact.js` (what is hidden), `Report.js` (the text), `Cpu.js`, `Log.js`, `Codes.js`, `Allow.js`. `scripts/diagnose.sh` builds the same report from a terminal when the shell does not answer; its cleaning rules mirror `Redact.js` and both sides are tested (`tests/diagnostics.test.js`, `tests/diagnose.test.sh`).
- `components/settings/ReportRow.js`: every word and state of the "Copy report" row.
- `components/settings/Sections.js`: the settings sections and every setting as one table (keys, help, synonyms, battery level); `components/settings/Search.js`: the settings search over it (copied from Orbit's engine, typo-tolerant, ranked), both used by `SettingsPage.qml`.

**Motion timers.** Nothing animates with QML animations while idle. The pill's single motion clock is `components/PillClock.qml`, driven by `HorizontalPill.qml`: 16 ms only for the bell swing, 33 ms for the final-countdown beat and the breathing; it runs only while ringing or beating and stops after the alarm duration. The panel's sand clock is `components/hourglass/MotionClock.qml` (33 ms once the sand is settled, stopped under Reduce motion).

Timers are stored as **end times**, not countdowns, so they survive a restart.

## Project layout

```
Sands/
├── plugin.json                 # manifest: id, version, components, permissions
├── TimerDaemon.qml             # engine (see Architecture)
├── TimerWidget.qml             # host wiring: picks the pills and the panel
├── TimerLauncher.qml           # launcher provider
├── TimerSettings.qml           # settings page
├── TimeParser.js               # natural-language parser + formatting (tested)
├── lang/                       # language packs of the parser and commands: en.js, fr.js
├── Commands.js                 # launcher commands on running timers: intent, target, preview (tested)
├── Timers.js                   # pure timer logic: time left, recents ranking… (tested)
├── Preview.js                  # launcher preview lines: « Pasta · 12 min · ends 12:42 » (tested)
├── Guide.js                    # "why it can't be done" notes + guide anchors (tested)
├── components/
│   ├── HorizontalPill.qml      # horizontal bar pill: state, layout (uses the Pill* parts below)
│   ├── VerticalPill.qml        # vertical bar pill: ring + short time
│   ├── PillGlyph.qml, PillNameLabel.qml, PillTimeLabel.qml, PillBadge.qml  # one part each of the horizontal pill
│   ├── PillClock.qml           # the pill's 30/60 Hz motion clock and the ringing limit
│   ├── HoverDwell.qml          # damped hover (opens after 120 ms, closes after 450 ms)
│   ├── PillClicks.qml          # middle click and wheel on the pill
│   ├── daemon/                 # the engine's parts, one role per file (see Architecture)
│   │   ├── TimerStore.qml, AlarmSound.qml, TimerNotifier.qml, TimerIpc.qml
│   │   ├── ReportService.qml, ReportClipboard.qml, ToolProcess.qml   # the anonymous report, on demand only
│   │   └── Lifecycle.js, Sound.js, Notifications.js, IpcReplies.js, PlainText.js, Retired.js   (tested)
│   ├── alert/                  # "Rising dune" alert: DuneAlert (host), RingAlert (wiring to the engine), DuneWindows (layer window per screen), DuneBand (Loader, 30 Hz Timer, legend), GrainsScene (Last grains), WindScene (Wind dune), WaveScene (Flat wave); pure logic DuneStyles.js, DuneMotion.js, SandTint.js, AlertPolicy.js, HaloMotion.js   (logic tested by gjs, band by tests/qml-dune/run.sh)
│   ├── TimerPanelContent.qml   # panel: state, switching between timers, wiring of the parts below
│   ├── PanelGlass.qml          # hourglass, gestures (GlassGestures), dots (TimerDots), frost (FrostMist, FrostDust)
│   ├── PanelClock.qml          # name, big time, end time (FrostHalo behind it)
│   ├── AdjustChips.qml         # −1 / +1 / +5 min
│   ├── PanelControls.qml       # cancel, pause/resume, restart; StopButton once finished
│   ├── OtherTimers.qml         # the other timers, one OtherTimerRow each
│   ├── Hourglass.qml           # the floating hourglass: only wires the pieces of hourglass/
│   ├── hourglass/              # one role per file: Geometry.js (sizes, volumes; tested), Colors.js, FrostDraw.js (tested),
│   │                           #   MotionClock (the one Timer), Turn (flip, wild), SandLevel (eased level), SandStream (grains),
│   │                           #   Glass (the glass canvas), Halos/Halo, Shadow, GotSlot (Loader)/GotLayer/GotBack/GotFront/GotPalette (Glass of Time)
│   ├── settings/               # Sections.js (settings table, helpers), Search.js (search)   (tested)
│   │                           #   "Copy report" row: CopyReport (row), ReportButton (an OutlineButton with its check and heap), ReportMark (GitHub link), ReportRow.js (words and states, tested)
│   ├── FocusRing.qml, Press.js # the keyboard focus ring; keys, target size and fades of the hand-drawn controls
│   ├── ProgressRing.qml        # the ring used in the pill and lists
│   ├── HelpNote.qml            # the short note at the top of the panel
│   ├── GitHubMark.qml          # GitHub logo that opens the guide section
│   ├── RoundButton.qml, Chip.qml
│   └── Motion.js               # looping motion as pure functions of time (tested)
├── components/journal/         # the time journal screen: JournalView (one Loader, two looks), Strata, Threads, Swatch, ElidedName, Journal.js (pure rules, tested)
├── sounds/                     # the shipped rings (hourglass.ogg, silt-chime.ogg)
├── tools/sounds/               # renders hourglass.ogg (python3 tools/sounds/generate.py OUT), check.py inspects rings; README.md lists hashes
├── diagnostics/                # the anonymous report as pure rules: Gather.js, Redact.js, Report.js, Cpu.js, Log.js, Codes.js, Allow.js   (tested)
├── scripts/diagnose.sh         # the same report from a terminal, for when the shell does not answer (tested by tests/diagnose.test.sh)
├── scripts/lint.sh             # qmllint against scripts/lint-baseline.txt, rule levels in .qmllint.ini (tested by tests/lint.test.sh)
├── scripts/preview/            # offscreen scenes, mocks and reference pictures (never loaded by the plugin)
├── tests/
│   ├── parser.test.js, commands.test.js
│   ├── motion.test.js
│   ├── timers.test.js
│   ├── lifecycle.test.js, sound.test.js, daemon-text.test.js, daemon-surface.test.js
│   ├── hourglass.test.js, journal.test.js, journal-layout.sh
│   ├── qml-daemon/             # the real daemon end to end: run.sh, shell.qml (scene), check.js (assertions)
│   ├── harness.js              # shared loader for the daemon tests
│   ├── preview.test.js
│   └── guide.test.js
└── docs/
    ├── GUIDE.md                # user guide
    └── images/                 # screenshots and animations
```

## Panel parts

The panel parts show what they are given and report what the user does with signals; only `TimerPanelContent.qml` talks to the daemon's state and decides. Parts that are only needed sometimes (frost while a timer is paused, the list of other timers) sit behind a `Loader` whose `active` follows the need, so they cost nothing the rest of the time. After touching them, run `scripts/preview/shots.sh` and `scripts/preview/cmp.sh`: the panel scenes must stay identical to `scripts/preview/reference/`.

## Tests

```sh
sh tests/run-all.sh          # full, about 1 min: run it before every commit
sh tests/run-all.sh --fast   # a few seconds, while working
```

`--fast` runs every `tests/*.test.js` with `gjs` and every `tests/*.test.sh` with `sh`. The full run adds, side by side, every `tests/*/run.sh` (the offscreen QML runners, the daemon end to end), `tests/journal-layout.sh`, the settings overlap scene and `scripts/lint.sh`. It needs `gjs`, `qml-qt6`, `qmltestrunner-qt6`, `quickshell` and the DMS install. A failure does not stop it: it prints the end of each failed job's output, then one line per job (name, ok/FAIL, seconds), and exits 1 if any failed. A new test that follows these names is picked up on its own; `tests/run-all.test.sh` tests the runner. One job alone: `gjs tests/parser.test.js`, `sh tests/qml/run.sh`...

Daemon end to end (real Quickshell offscreen, staged like `daemon-loop.sh`): `tests/qml-daemon/run.sh` runs `TimerDaemon.qml` twice in a throw-away home, with stand-ins on `PATH` that record their arguments (`pw-play`, `paplay`, `notify-send`, `gdbus`, `wl-copy`, `dms`, `niri`). First run, from the settings of an older Sands (its end mode): those keys are dropped once and nothing else changes, then a 2 s timer rings; it checks the `pw-play` and `notify-send` arguments and timing (rising volume, 450 ms gap, no sound before the end), the dune (up at the ring, named after the timer), the saved plugin state, the journal line and its file modes; every plugin counts as loaded, and none is told anything. A second timer ends while no shell runs. Second run, from the saved state: the timers come back, both ended ones ring and are notified again, the dune is named after the last to end, each stop closes its own notification (`gdbus`) and the last one, a click on the dune, silences the alarm and takes the dune down. An `AudioService` stand-in gives one unmuted output. `shell.qml` acts and reports, `check.js` judges; it fails (exit 1) with the name of each broken check, and on any script error (`ReferenceError`, `TypeError`...) in either run's log. A change to what the end of a timer does must update `check.js` in the same commit.

Settings keys and reveal (real key events, needs `qmltestrunner-qt6`): `tests/qml-page/run.sh` checks Ctrl+F, `/`, typing, Esc, Enter and the scroll of a picked row inside a Flickable, and `tst_sections.qml` checks that every section is built with the page and that walking the rail repeatedly never builds or drops one (NAK-708).

Settings overlap (offscreen, needs `qml-qt6`): `cd scripts/preview && TZ=UTC QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml-qt6 -I imports settings-overlap.qml` loads the settings page at 228, 360 and 404 px and exits 1 on any overlap, elided text or text off the page. `scripts/preview/before-after.sh <commit> <out.html>` builds the before/after page (dark and light, two widths, four made-up stores; stores live in `scripts/preview/mock/Presets.js`).

Every new syntax goes with a test in `tests/parser.test.js` (a launcher command: `tests/commands.test.js`); a new word goes in the pack of its language, with a case in that pack's list of `PACK_CASES`.

### Lint

```sh
sh scripts/lint.sh            # qmllint over every QML file (not scripts/preview/), about 2 s
sh scripts/lint.sh --update   # after fixing warnings, or when one is accepted on purpose
```

The warnings that were already there are listed in `scripts/lint-baseline.txt` (file, rule, message, code; no line number, so moving code does not touch it). Only a new one fails (exit 1, printed with its line); a fixed one is only reported. The DMS modules come from the stand-ins in `scripts/preview/imports`, Quickshell from its install, the rule levels from `.qmllint.ini`. Never refresh the baseline to hide a new warning: fix it. `sh tests/lint.test.sh` tests the script.

## Offscreen previews and bench

`scripts/preview/` renders the real `TimerWidget.qml` (pill and panel), `TimerPanelContent.qml` and `Hourglass.qml` with a made-up daemon (`mock/FakeDaemon.qml`), made-up timers and stand-ins for the DMS modules (`imports/qs/*`). Nothing of the live shell is read or touched, and the plugin never loads anything from this folder. It needs `qml-qt6` (Qt 6) and the DMS install for the Material Symbols font.

```sh
scripts/preview/shots.sh                               # every scene of manifest.txt, as PNGs in out/ (ignored by git)
scripts/preview/shots.sh /tmp/sands-shots              # the same, in another folder
scripts/preview/shots.sh /tmp/sands-shots panel pill-4 # only some of them
scripts/preview/cmp.sh /tmp/sands-shots                # compare with scripts/preview/reference/
TZ=UTC QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml-qt6 -I scripts/preview/imports scripts/preview/launcher.qml   # launcher: prints each query's lines as text
TZ=UTC QT_QPA_PLATFORM=offscreen qml-qt6 -I scripts/preview/imports scripts/preview/launcher-shot.qml -- out.png   # docs/images/launcher.png: the launcher row from made-up input, fixed clock
TZ=UTC QT_QPA_PLATFORM=offscreen qml-qt6 -I scripts/preview/imports scripts/preview/launcher-section.qml -- out.png [variant] [light] [reduce]   # the Timers row of Spotlight; variants: one, four, ringing, favourites, stopped, expanded, narrow, ringing-open, all (default)
```

Scenes (`shot.qml -- <scene> <out.png>`): `pill-idle`, `pill-running`, `pill-label` (right after a start), `pill-done`, `pill-4`, `panel`, `panel-paused`, `panel-ringing`, `panel-4` (four 1 h timers), `hourglass-running`, `hourglass-frozen`, `hourglass-ringing`. Bench-only scenes (not in the reference set): `pill-beat`, `pill-bell`, `pill-short`. The suffix `-reduce` turns Reduce motion on.

**Refactors must keep the pictures.** `cmp.sh` checks each picture against `reference/` and the hash in `manifest.txt`. A scene is byte-identical (tolerance 0) when nothing moves: the pills and most `-reduce` scenes (`panel-4-reduce` and `panel-ringing-reduce` showed 3 and 5 px in some runs, so they have 10). The scenes with sand and float moving carry a few pixels of noise between two runs of the same code (0 to 7 px measured), so they have a small tolerance in `manifest.txt`. When a change is meant to alter the look, re-render and run `cmp.sh --update <dir>` in the same commit, and say why in the message.

**Bench (`outils/banc-ab.sh`).** Add `-hold` to a scene and it takes no picture: it keeps running on the real clock until stopped, which is what the A/B bench wants. Both revisions run the very same scenes through `-s`:

```sh
banc-ab.sh -s scripts/preview <repo> <refA> <refB> -- \
  sh -c 'cd scripts/preview && exec qml-qt6 -I imports shot.qml -- panel-hold /dev/null'
```

The whole daemon (`TimerDaemon.qml` and every part it loads) has its own scene, run by the real Quickshell offscreen in a throw-away home, with stand-ins on `PATH` for the sound players, `notify-send`, the clipboard tools, `dms` and `niri`. It also runs an older revision, so both sides of a bench load the same scene:

```sh
sh scripts/preview/daemon-loop.sh idle      # daemon loaded, nothing asked
sh scripts/preview/daemon-loop.sh run       # one 1 h timer
sh scripts/preview/daemon-loop.sh report    # one anonymous report every 12 s, with the real read-only probes
banc-ab.sh -s scripts/preview <repo> <refA> <refB> -- sh scripts/preview/daemon-loop.sh idle
```

It prints `sands-bench ready <mode>` on stderr once loaded (the start-up measure waits for it). `report.qml` is the report service alone with mock tools; `daemon.qml` (mock processes, `qml-qt6`) no longer loads since the alert windows need a layer shell.

Useful cases: `panel-hold` (sand flowing), `panel-paused-hold` (frozen), `pill-done-hold` (alarm pill), `panel-4-hold`, `hourglass-running-hold`, plus `-reduce`. `outils/essai.sh Sands <commit>` opens `panel-hold` in a window (see `essai.conf`).

When you change a stand-in, keep it as small as the real module's surface Sands uses; if Qt prints anything while rendering, `shots.sh` lists the log (a missing property in a stand-in shows up there).

## Performance rules

Sands must cost nothing while nobody looks at it. Keep these rules when changing the code:

- **Never loop a QML animation** (`NumberAnimation` with `loops`, `Animator`, `FrameAnimation`). A looping animation keeps Qt's shared animation clock ticking, and then *every* DMS window (bars, wallpaper) redraws at the display rate. One plain `Timer` drives all the motion instead: 60 fps while grains fall or the bell shakes, 30 fps for slow motion, with positions from `Motion.js`.
- **Wake only when needed**: the engine wakes when a displayed second changes, not at all when everything is paused.
- **Redraw only what moved**: glass and sand are repainted only when the sand level moves by at least a quarter pixel; floating, grains and the flip are GPU transforms.
- **Closed panel**: every animation stops.
- **Honor DMS Reduce motion.**

Measure before and after a change, in % of one CPU core for the whole shell (240 Hz display, DMS alone: about 2 %):

| Situation | 1.2.1 | 1.3.0 |
| --- | --- | --- |
| Timer running, panel closed | Same as DMS alone | Same as DMS alone (2.1 %) |
| Panel open, sand flowing | 87 % | 6.5 % |
| Panel open, paused (frozen) | 105 % | 3.9 % |

## Conventions

- **Language**: code, comments, UI and docs in English. The launcher accepts English and French input.
- **Comments**: each file starts with a short comment saying what it is and why.
- **Privacy**: no network access and no telemetry, ever. Nothing written to disk except timers and settings through DMS.
- **Colors**: always from the DMS theme, never hard-coded.
- **Docs**: user-facing changes go in `docs/GUIDE.md` (and the README if they change installation or the basics), plus an entry in `CHANGELOG.md`.

## Releasing a version

1. Bump `version` in `plugin.json` ([Semantic Versioning](https://semver.org/)).
2. Move the `Unreleased` entries of `CHANGELOG.md` under the new version and date.
3. Refresh the images in `docs/images/` if the look changed.
4. Run the tests, commit, then tag: `git tag v1.4.1 && git push --tags`.
