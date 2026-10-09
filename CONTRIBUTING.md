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
   git clone https://github.com/lung595/Sands ~/.config/DankMaterialShell/plugins/Sands
   ```

2. Add the **Sands** widget to the bar to see the pill and the panel.
3. DMS reloads QML on save, but Qt keeps `components/` and `.js` files cached in the running shell: **run `dms restart`** after changing them.

Tools: `gjs` (tests).

## Architecture

`plugin.json` declares a **composite** plugin with the id `smartTimer` (used by the IPC target, the settings and the saved state; do not rename it, or users lose their data):

| Component | File | Role |
| --- | --- | --- |
| Daemon | `TimerDaemon.qml` | The engine, one instance: the timer list, its actions and the clock. Delegates to `components/daemon/` |
| Widget | `TimerWidget.qml` | Bar pill and its popout (the panel). Only displays the daemon's state and forwards actions |
| Launcher | `TimerLauncher.qml` | Launcher provider: answers only when the input looks like a duration |
| Settings | `TimerSettings.qml` | Settings page |

The widget and the launcher reach the engine through `PluginService.pluginDaemonInstances["smartTimer"]`.

The daemon is split by role, one file each, in `components/daemon/`. Each QML file only wires; its rules are in the `.js` next to it:

| File | Role | Pure logic |
| --- | --- | --- |
| `TimerStore.qml` | Persistence through the DMS plugin state | |
| `AlarmSound.qml` | Every sound: alarm, settings preview, tick (one idle `Process` each) | `Sound.js` |
| `TimerNotifier.qml` | End notification with Stop / +5 min (one `notify-send` per ringing timer) | `Notifications.js` |
| `TimerIpc.qml` | The `dms ipc call smartTimer …` commands | `IpcReplies.js` |
| | State transitions, expiry, next wake-up, restore | `Lifecycle.js` |

Logic that can be tested lives in **pure `.js` files** with no QML:

- `TimeParser.js`: natural-language parser (English and French) and formatting.
- `Timers.js`: pure timer logic (time left, progress, names, recents ranking, colour slots) that `TimerDaemon.qml` calls with its clock.
- `components/daemon/*.js`: the rules of the daemon's parts (see the table above). They import `TimeParser.js` and `Timers.js` where needed.
- `Guide.js`: the short notes shown when something can't be done (title, hint, guide anchor); a test checks every anchor exists in `docs/GUIDE.md`.
- `components/Motion.js`: every looping motion as a pure function of time.

Timers are stored as **end times**, not countdowns, so they survive a restart.

## Project layout

```
Sands/
├── plugin.json                 # manifest: id, version, components, permissions
├── TimerDaemon.qml             # engine (see Architecture)
├── TimerWidget.qml             # bar pill + native DMS popout
├── TimerLauncher.qml           # launcher provider
├── TimerSettings.qml           # settings page
├── TimeParser.js               # natural-language parser + formatting (tested)
├── Timers.js                   # pure timer logic: time left, recents ranking… (tested)
├── Guide.js                    # "why it can't be done" notes + guide anchors (tested)
├── components/
│   ├── daemon/                 # the engine's parts, one role per file (see Architecture)
│   │   ├── TimerStore.qml, AlarmSound.qml, TimerNotifier.qml, TimerIpc.qml
│   │   └── Lifecycle.js, Sound.js, Notifications.js, IpcReplies.js   (tested)
│   ├── TimerPanelContent.qml   # panel: state, switching between timers, wiring of the parts below
│   ├── PanelGlass.qml          # hourglass, gestures (GlassGestures), dots (TimerDots), frost (FrostMist, FrostDust)
│   ├── PanelClock.qml          # name, big time, end time (FrostHalo behind it)
│   ├── AdjustChips.qml         # −1 / +1 / +5 min
│   ├── PanelControls.qml       # cancel, pause/resume, restart; StopButton once finished
│   ├── OtherTimers.qml         # the other timers, one OtherTimerRow each
│   ├── Hourglass.qml           # the floating hourglass: only wires the pieces of hourglass/
│   ├── hourglass/              # one role per file: Geometry.js (sizes, volumes; tested), Colors.js, FrostDraw.js (tested),
│   │                           #   MotionClock (the one Timer), Turn (flip, wild), SandLevel (eased level), SandStream (grains),
│   │                           #   Glass (the glass canvas), Halos/Halo, Shadow, GotLayer/GotBack/GotFront/GotPalette (Glass of Time)
│   ├── ProgressRing.qml        # the ring used in the pill and lists
│   ├── HelpNote.qml            # the short note at the top of the panel
│   ├── GitHubMark.qml          # GitHub logo that opens the guide section
│   ├── RoundButton.qml, Chip.qml
│   └── Motion.js               # looping motion as pure functions of time (tested)
├── sounds/                     # the shipped rings (hourglass.ogg, silt-chime.ogg)
├── tools/sounds/               # renders hourglass.ogg (python3 tools/sounds/generate.py OUT), check.py inspects rings; README.md lists hashes
├── scripts/preview/            # offscreen scenes, mocks and reference pictures (never loaded by the plugin)
├── tests/
│   ├── parser.test.js
│   ├── motion.test.js
│   ├── timers.test.js
│   ├── lifecycle.test.js, sound.test.js, daemon-text.test.js, daemon-surface.test.js
│   ├── hourglass.test.js
│   ├── harness.js              # shared loader for the daemon tests
│   └── guide.test.js
└── docs/
    ├── GUIDE.md                # user guide
    └── images/                 # screenshots and animations
```

## Panel parts

The panel parts show what they are given and report what the user does with signals; only `TimerPanelContent.qml` talks to the daemon's state and decides. Parts that are only needed sometimes (frost while a timer is paused, the list of other timers) sit behind a `Loader` whose `active` follows the need, so they cost nothing the rest of the time. After touching them, run `scripts/preview/shots.sh` and `scripts/preview/cmp.sh`: the panel scenes must stay identical to `scripts/preview/reference/`.

## Tests

```sh
gjs tests/parser.test.js        # 108 parser tests
gjs tests/motion.test.js
gjs tests/timers.test.js        # 25 timer logic tests
gjs tests/guide.test.js         # 18 tests: note length, guide anchors
<<<<<<< HEAD
gjs tests/lifecycle.test.js     # 48 tests: transitions, expiry, wake-up, restore
gjs tests/sound.test.js         # 33 tests: sound file and rings, volume, ramp, player command
gjs tests/daemon-text.test.js   # 22 tests: IPC sentences, notification commands
gjs tests/daemon-surface.test.js # 21 tests: every daemon member a view reads is still declared
=======
gjs tests/hourglass.test.js     # 23 checks: hourglass geometry, volumes, frost shapes
>>>>>>> 87e040d (refactor(hourglass): split Hourglass.qml into single-role files, gjs-tested geometry (NAK-143))
```

Run them all before every commit. Every new syntax goes with a test in `tests/parser.test.js`.

## Offscreen previews and bench

`scripts/preview/` renders the real `TimerWidget.qml` (pill and panel), `TimerPanelContent.qml` and `Hourglass.qml` with a made-up daemon (`mock/FakeDaemon.qml`), made-up timers and stand-ins for the DMS modules (`imports/qs/*`). Nothing of the live shell is read or touched, and the plugin never loads anything from this folder. It needs `qml-qt6` (Qt 6) and the DMS install for the Material Symbols font.

```sh
scripts/preview/shots.sh /tmp/sands-shots              # every scene of manifest.txt, as PNGs
scripts/preview/shots.sh /tmp/sands-shots panel pill-4 # only some of them
scripts/preview/cmp.sh /tmp/sands-shots                # compare with scripts/preview/reference/
```

Scenes (`shot.qml -- <scene> <out.png>`): `pill-idle`, `pill-running`, `pill-label` (right after a start), `pill-done`, `pill-4`, `panel`, `panel-paused`, `panel-ringing`, `panel-4` (four 1 h timers), `hourglass-running`, `hourglass-frozen`, `hourglass-ringing`. The suffix `-reduce` turns Reduce motion on.

**Refactors must keep the pictures.** `cmp.sh` checks each picture against `reference/` and the hash in `manifest.txt`. A scene is byte-identical (tolerance 0) when nothing moves: the pills and most `-reduce` scenes (`panel-4-reduce` and `panel-ringing-reduce` showed 3 and 5 px in some runs, so they have 10). The scenes with sand and float moving carry a few pixels of noise between two runs of the same code (0 to 7 px measured), so they have a small tolerance in `manifest.txt`. When a change is meant to alter the look, re-render and run `cmp.sh --update <dir>` in the same commit, and say why in the message.

**Bench (`outils/banc-ab.sh`).** Add `-hold` to a scene and it takes no picture: it keeps running on the real clock until stopped, which is what the A/B bench wants. Both revisions run the very same scenes through `-s`:

```sh
banc-ab.sh -s scripts/preview <repo> <refA> <refB> -- \
  sh -c 'cd scripts/preview && exec qml-qt6 -I imports shot.qml -- panel-hold /dev/null'
```

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
