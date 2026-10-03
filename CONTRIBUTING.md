# Contributing

Everything needed to work on Sands or take over the project.

## Contents

- [Development setup](#development-setup)
- [Architecture](#architecture)
- [Project layout](#project-layout)
- [Tests](#tests)
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
| Daemon | `TimerDaemon.qml` | The engine, one instance: timers, persistence, sound, notifications, IPC |
| Widget | `TimerWidget.qml` | Bar pill and its popout (the panel). Only displays the daemon's state and forwards actions |
| Launcher | `TimerLauncher.qml` | Launcher provider: answers only when the input looks like a duration |
| Settings | `TimerSettings.qml` | Settings page |

The widget and the launcher reach the engine through `PluginService.pluginDaemonInstances["smartTimer"]`.

Logic that can be tested lives in **pure `.js` files** with no QML:

- `TimeParser.js`: natural-language parser (English and French) and formatting.
- `Timers.js`: pure timer logic (time left, progress, names, recents ranking, colour slots) that `TimerDaemon.qml` calls with its clock.
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
│   ├── TimerPanelContent.qml   # panel: hourglass, time, controls, other timers
│   ├── Hourglass.qml           # the floating, volume-synced hourglass
│   ├── ProgressRing.qml        # the ring used in the pill and lists
│   ├── HelpNote.qml            # the short note at the top of the panel
│   ├── GitHubMark.qml          # GitHub logo that opens the guide section
│   ├── RoundButton.qml, Chip.qml
│   └── Motion.js               # looping motion as pure functions of time (tested)
├── tests/
│   ├── parser.test.js
│   ├── motion.test.js
│   ├── timers.test.js
│   └── guide.test.js
└── docs/
    ├── GUIDE.md                # user guide
    └── images/                 # screenshots and animations
```

## Tests

```sh
gjs tests/parser.test.js        # 108 parser tests
gjs tests/motion.test.js
gjs tests/timers.test.js        # 34 timer logic tests
gjs tests/guide.test.js         # 18 tests: note length, guide anchors
```

Run them all before every commit. Every new syntax goes with a test in `tests/parser.test.js`.

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
