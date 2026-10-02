# Changelog

All notable changes to Sands are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

## 1.4.2 - 2026-10-02

### Security

- At most 50 timers run together, and `4x 1h` is saved in a single write instead of one per timer.
- `dms ipc call smartTimer add` can no longer push a timer past 100 hours.
- `pw-play` gets `--` before the sound path.
- A query longer than 200 characters is answered at once with a short note instead of being parsed (a 20,000-character text took 165 ms before, 0 ms now), and a label keeps its first 60 characters.

### Changed

- Nothing is refused silently: a launcher query Sands can't read, `99x` (now clamped to 20), a full timer list or an out-of-range `add` show a short message with a link to the *Syntax* section of the guide.

### Fixed

- The pill stops moving while the session is locked or the screens are off; the alarm sound still rings.

## 1.4.1 - 2026-10-02

### Changed

- The timer logic (time left, progress, recents ranking) moved out of the daemon into `Timers.js`, with 25 tests; nothing changes on screen.
- Documentation split into `README.md`, `docs/GUIDE.md`, `CHANGELOG.md`, `ROADMAP.md` and `CONTRIBUTING.md`.

### Fixed

- `Space` really pauses and resumes the timer shown in the panel. It is a window shortcut now: DMS gives the keyboard focus to its own popout container, an ancestor of the panel, and a key event only travels upwards, so a `Keys` handler on the panel never saw it.

## 1.4.0 - 2026-10-01

### Added

- Repeat a duration: `4x 1h`, `4* 1h`, `1h x4` start four timers (up to 20) and count once in your recents.
- `timer stop` in the launcher cancels directly, or asks which timer when there are several.
- `Space` pauses and resumes the timer shown in the panel.

### Changed

- Clicking the hourglass plays a spin-and-hop animation instead of restarting the timer. Restart stays on its button.
- A ringing alarm nobody answers stops moving after the *Alarm duration*, like its sound: the pill stays red but no longer redraws the bar.
- The panel follows the theme more closely (text on the main button, frost color and crystals, clock and icon sizes). The frost stays an ice blue, but darker on a light theme.
- Declared dependencies: `pw-play`, `libnotify`, `glib2`.

### Fixed

- The *Stop* button text uses the theme's `onError` color (it was an unknown token).

## 1.3.0 - 2026-09-26

### Changed

- Ultra light: the open panel no longer makes the whole shell redraw at the display rate. Open panel 87 % → 6.5 % of one CPU core, paused panel 105 % → 3.9 %. Same motion as before.
- A ringing alarm left alone no longer keeps the shell busy: the pill breathes at 30 fps and redraws only the bar.
- The settings examples show both input languages.
- With *Reduce motion*, the frozen aura no longer breathes.

### Removed

- The *Language* setting and the `lang` command: the interface is in English only. The launcher still understands English and French.

## 1.2.1 - 2026-09-26

### Changed

- *Reduce motion* is honored everywhere: no beat or bell shake in the pill, still frost crystals, and no frames at all while a paused hourglass stands still.
- Code comments and test output in English only.

### Added

- A *Privacy* section in the documentation.

## 1.2.0 - 2026-09-26

### Added

- *Hourglass* setting: *Classic*, or *Glass of Time* (a nod to Steven Universe). Sand, freeze and flip behave the same.

## 1.1.0 - 2026-09-24

### Added

- First release: natural-language timers in French and English from the launcher, the bar pill with its ring, the floating hourglass that freezes when paused and flips on restart, several named timers with their own theme color, timers that survive a restart.
- Progressive ringing, a final tick, Do Not Disturb, a notification with Stop and +5 min, `dms ipc call smartTimer …` commands.
