# Roadmap

Ideas, not promises, and no dates. Sands stays a simple timer: no network, nothing sent anywhere.

## Next version

1.7.0 shipped the *Timers* row of the launcher, the removals and the groundwork below. These parts of the 1.7 plan did not make it and come next.

### Reliability

- **Sound fallback**: when `pw-play` is missing, try `paplay`, then `aplay`. If no player works, the visual alert shows anyway, a toast says « No audio player found » once per session, and the report gets a code (`SND-E004`; `SND-E003` when `notify-send` is missing).
- **Saved timers checked on load**: a broken entry is skipped and logged (`SND-E002 bad_timer`), the others are kept, and the file is written back clean. Emoji are removed from saved names; a name that was only an emoji becomes « Timer ». The code exists but has not been reviewed yet.

### Wiring the 1.7.0 groundwork

The modules are in 1.7.0 and tested, but the views do not use them yet (see the notes in CONTRIBUTING).

- **Launcher commands** (`Commands.js`): `timer +5`, `timer -2 pâtes`, `pause pâtes`, `reprendre`, `snooze 10`, `renomme pâtes en riz`. With no name, the command applies to the nearest timer. The row shows the target before Enter.
- **Known durations** (`KnownDurations.js`): « timer pâtes » with no number offers « Pâtes — 10 min ». Your last time for that name comes before the built-in table.
- **French and English interface** (`Strings.js`): convert the QML views so every screen follows the DMS language.
- **12/24 h everywhere** (`TimeFormat.js`): every view follows the DMS clock setting.

### Everyday use

- **Snooze everywhere**: chips in the ringing row, « +N min » on the dune and halo caption, on the ringing launcher card and on the notification. Three durations in *Alerts & sounds* (default 1 / 5 / 10 min); the last one used comes first.
- **Notice before the end**: a DMS toast « Pâtes: 2 min left ». Setting: Off / 1 / 2 / 5 min, default 2, only for timers longer than twice the notice.
- **Hourglass at rest** (off by default): an empty, still hourglass in the bar when nothing runs. A click opens the panel with the favourites.

### Plans (Pomodoro and chains)

- Type « 4x 25/5 » or « pâtes 10 puis sauce 5 » and see a preview first. The daemon keeps the plan and runs the steps in order.
- A long break only when typed (« 4x 25/5 long 15 »).
- *Chain automatically*, on by default: a short sound between steps and the normal ring at the end. Off: each step rings and waits.
- Step dots on the cards. The pill shows the step name, or « 2/8 » when space is short.

### Accessibility

- Stopping from the keyboard: document `dms ipc call smartTimer stop` (no default key: you choose yours). The dune never takes the keyboard. Its caption is announced as an alert.
- The panel works with the keyboard: Tab focus, Enter/Space, a focus ring and accessible names on the round buttons, chips and timer rows.

### Performance and code

- No 1 Hz wake-up while a timer rings. History cached in memory instead of read from disk at each opening. One wake-up for any number of timers.
- `scripts/bench.sh` measures the dune, halo, journal, favourites and launcher row, and the GUIDE table is updated.
- One reactive read of the settings. Folders sorted into `lib/`, `pill/` and `panel/`, and a lighter daemon. The largest files (`Hourglass.qml`, `TimerDaemon.qml`) are split by role, without changing behavior.

### Launcher row

- Check the keyboard inside an open card in a real session. So far only the offscreen tests cover it.
- In the *spotlight-bar* style with an empty search, DMS lists nothing, so the row is hidden until you type. This is how DMS behaves today.

## Waiting on DankMaterialShell

The *Timers* row needs *live launcher sections* in DMS, which plugins use to show a row that updates while the launcher is open. The change is proposed upstream. It covers Spotlight and the island launcher, not the app drawer. Until a DMS release includes it, the `dms-launcher-patch` tool applies it locally and a dnf hook applies it again after each DMS update. Without it, Sands works as before and the row does not show.

## Later

- **More input languages**: the launcher understands English and French today. Other languages are added on request: [open an issue](https://github.com/lung595/Sands/issues) to ask for yours.
- **Better sound design**: Hourglass and Silt Chime ship today. More rings are added only if they are made for Sands or free to share with credit.
