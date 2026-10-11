# Changelog

All notable changes to Sands are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Fixed

- Quickshell crashed when the settings page switched to "Alerts & sounds" (NAK-708). The page no longer builds a section on demand: all five are built with the page and only shown or hidden, as before the rail. Cause not proven (a `Loader` with a deferred Popup is suspected); covered by `tests/qml-page/tst_sections.qml`.

### Added

- Settings, *Alerts & sounds*: "Show on" chooses which screen shows the visual alert, dune and halo alike, also for "Test the alarm": All screens (default, as before), Active screen (the one with the focus when the timer ends, asked from the DMS `CompositorService`) or one screen by name. Saved as `alertScreen` (`all`, `focused` or an output name such as `DP-2`); a screen that is unplugged, or a focus the compositor does not report, gives all screens, never none (`AlertPolicy.screensFor`). Found by the search ("screen", "monitor", "écran"). Covered by `tests/alert-policy.test.js` and `tests/qml-page/tst_alertRows.qml`; the layer-shell windows themselves are not covered by a test.
- Settings, *Alerts & sounds*: the visual alert can be chosen (NAK-681, NAK-663). Three cards for the kind (Rising dune, Edge halo, None; Edge halo is greyed with a note and the GitHub mark to the guide when the session has no layer shell), one card per Rising dune style (only Last grains has a scene today: Wind dune and Flat wave are greyed and marked "Not available yet", and a saved one is shown as Last grains, which is what is drawn), a "Show above full screen" switch for the dune, "Show the visual alert" (Every time, the default, or When sound is off) and a "Test the alarm" button that plays the sound and asks the daemon for one test alert (fake name "Pasta", stops by itself or on a click). The rows save the keys the daemon already read (`alertKind`, `duneStyle`, `duneOverFullscreen`, `alertWhen`), and `RingAlert` reads them again when the plugin data changes, so a choice applies to the next ring. All five rows are found by the search. Covered by `tests/qml-page/tst_alertRows.qml`, `tests/dune-styles.test.js`, `tests/settings-search.test.js` and `tests/settings-sections.test.js`; the layer-shell windows themselves are not covered by a test.
- Settings: one row per end action with its launcher words, your own commands (add, edit, remove) and an Erase history button (NAK-656). Not yet: nothing runs the saved commands and words when a timer ends until the end action runner lands.
- Pinned favourites in the panel (NAK-653): the three named timers started at least twice and most often, as "Three glasses" tiles (default) or "Rows", one click or Enter starts one again with the same name and duration; read from the journal when the panel opens only, one `Loader` for the look, the glass turns once (300 ms, none with Reduce motion). The look follows `Variants.js`; the settings rows come later. `History.favourites` also returns the duration of the latest start. A start the daemon refuses is not shown as started; the preview scene is `scripts/preview/favourites-shot.qml`. Covered by `tests/pins.test.js` and `tests/qml-page/tst_favourites.qml`.
- Settings page with a left section rail (NAK-262, option A "Dune"): Timers, Appearance, Alerts & sounds and Help (the launcher examples and the command line moved there from Timers), one section shown at a time, all built with the page, a search bar on top (names, help, synonyms in English and French, typos forgiven; Enter opens the first hit, Esc clears, Ctrl+F or / focuses) that opens the found setting's section and fades a highlight over its row once (150 ms with Reduce motion). The rail becomes a stack under 400 px. Saved keys, values and defaults unchanged. Section logos are drawn as stroked shapes in the theme colour. Not yet: the pending settings of NAK-395. A pick whose row is hidden by the current state (Prefix, Sound file) highlights the row it depends on, and "Examples and commands" highlights the Help block; the page scrolls the found row into view when it sits in a flickable; Esc only clears a non-empty query and Ctrl+F and / are window shortcuts active while the Sands page is shown (/ is ignored while a text field has the focus). `scripts/preview/rail-scenes.sh` renders the scenes (default, result, no result, narrow, light, dark, Reduce motion).
- Pure logic for the visual alert (`components/alert/AlertPolicy.js`, `HaloMotion.js`, NAK-679): which alert to draw (dune, Edge halo, none) and when (when the sound is off, or every time; hidden over full screen unless allowed), and the finite steps of the Edge halo (rise, 3 beats at 30 Hz, rest; Reduce motion shows the posed rim only). Not wired to any view yet; covered by `tests/alert-policy.test.js` and `tests/halo-motion.test.js`.
- The time journal in the panel (NAK-652): a "This week" screen with the week's time per name, as Strata layers in a glass (default) or Threads bars, one `Loader` so only the chosen look exists, read from the daemon only when the screen opens. Pure logic in `components/journal/Journal.js`, covered by `tests/journal.test.js` and the offscreen layout test `tests/journal-layout.sh` (empty, one, many and very long names, narrow and wide, light and dark, Reduce motion).
- Edge halo scene and alert host (`components/alert/HaloScene.qml`, `DuneAlert.qml`, NAK-680): a 4 px primary rim in 200 ms, 3 beats, then still until dismissed, on every screen through layer shell; the host reads the kind and moment through `AlertPolicy`, holds one scene in a `Loader` that exists only while the alert shows, and offers `ring()`, `dismiss()` and `test()` (fake name "Pasta"). Not wired to the daemon yet (the dune scene and the wiring come with their own stories). Covered by `tests/qml/run.sh` and `tests/halo-contrast.test.js` (legend contrast 9.5:1 or more on every stock theme).
- Rising dune, style "Wind dune" (`components/alert/WindScene.qml`, NAK-661): the same matte sand as Last grains, blown in from the left edge with a travelling crest and grains that hop on the sand, a 1 px lit edge on the windward slope once settled, hard stop at 2.6 s; the legend shows once sand is behind all of it. Drawn for the saved value `wind`; a style picked while the alert shows starts its own run. `scripts/preview/dune.qml` takes `style=`. Not yet: the settings row to pick it. Covered by `tests/dune-motion.test.js` and `tests/qml-dune/run.sh` (each style loads its own scene, ends by itself, then no repaint; Reduce motion; 360 px).
- Rising dune, style "Flat wave" (`components/alert/WaveScene.qml`, NAK-662): one flat ridge in the primary colour that springs up past its height and thuds three times, with a rim along the crest, a base line, sand specks, eight round grains and fine sand thrown at each thud, hard stop at 2.4 s; the rim tint is raised until it reaches 3:1 against the primary (`SandTint.cel`). Drawn for the saved value `wave`. Not yet: the settings row to pick it. Covered by `tests/sand-tint.test.js` and `tests/qml-dune/run.sh`.
- Rising dune scene, default "Last grains", and the wiring of the alert host to the timer engine (`components/alert/RingAlert.qml`, `DuneWindows.qml`, `DuneBand.qml`, `GrainsScene.qml`, `SandTint.js`, NAK-660): when a timer rings, every time by default (the saved moment can limit it to when the sound cannot be heard), a 200 px band of sand rises along the bottom edge of every screen with the name of the timer, a click on the legend stops the ring, and nothing exists at rest. Several timers ending together share one dune named after the last one. The settings rows (kind, moment, style, full screen) come with their own stories; until then the defaults apply. Covered by `tests/sand-tint.test.js`, `tests/alert-policy.test.js` and `tests/qml-dune/run.sh`.
- The daemon raises a `noticeDue(id)` signal once per timer shortly before it ends (`components/daemon/NoticeRunner.qml`, NAK-648): one single-shot wake-up armed at `Notice.nextDueAt`, re-armed only when the timer list changes (the `noticeMinutes` setting is read then), nothing armed without an eligible timer. Default 2 min, 0 turns it off, silent; nothing is shown yet. Covered by `tests/qml/run.sh`.
- Pure logic for the four look choices (`components/settings/Variants.js`, NAK-646): the journal, favourites, notice and end-of-timer modes, with their keys, allowed values, defaults, English labels and `clean(key, value)`. Not wired to any view yet; covered by `tests/variants.test.js`.
- The daemon keeps each timer that rings in the private history (`HistoryStore`, NAK-647): one record at the ring through `History.js`, nothing while a timer runs or at rest; stopped timers are not kept. Read side on demand only (`historyThisWeek`, `historyFavourites`), `eraseHistory`, and the file and its folder are removed when the plugin is uninstalled (`HistorySweep`, a detached removal once the manifest is gone). Covered by `tests/qml/run.sh` and `tests/history.test.js`.
- "Rising dune" motion model (no view yet): three sand styles (`grains` default, `wind`, `wave`) with a fallback for unknown values, seeded 30 Hz steps that end by themselves, and the full-screen rule. Approved mockup in `docs/design/NAK-553/`.
- Settings, last row of *Alerts & sounds*: « When a Sands timer ends » (NAK-546). Three choices (Sands only, Sands + Alex reacts, Alarm in the Alex island) with a miniature bar showing what rings where. The value is owned by Alex: Sands reads it when the page opens, follows Alex's « mode changed » notice while the page is open and sends changes through `dms ipc call` (argument array, three fixed words), keeping no copy. Greyed with a short note and the GitHub mark to the guide when Alex is absent. Pure rules in `AlexBridge.js`; `scripts/preview/timer-end-row.qml` tests the row against a mocked Alex in both directions, at the narrow widths, with the 44 px control, 14 px labels and 4/8 px strip margins. The guide address now lives once, in `Guide.js`.

## 1.6.0 - 2026-10-11

### Added

- `dms ipc call smartTimer snooze <minutes>` (NAK-495): restarts the first ringing timer for 1 to 120 minutes (0: 5 minutes, like the notification button; out-of-range values are clamped). Always answers JSON, `{"snoozed":false,...}` when nothing rings, with no state change. `Snooze.forIpc`, covered by `tests/snooze.test.js`.
- One "timer finished" event for Alex at the ring (`AlexBridge.js`, NAK-494): published once per ended timer through `PluginService.setGlobalVar` (key `timerFinished`, fields `kind: "timerFinished"`, id, label capped at 60 characters, end time) and only when Alex is loaded; without Alex nothing is called and nothing changes. Sands keeps showing its own alarm, sound and bar pill. Several timers ending in the same tick write the key once each (a late reader sees the last). Covered by `tests/alex-bridge.test.js`.
- Pure parser for focus-cycle and chained-timer phrases (`Plans.js`, NAK-398). Not wired to any view yet; covered by `tests/plans.test.js`.
- Pure logic for the end-of-timer actions and the free launcher words (`EndActions.js`, `LauncherWords.js`, NAK-399). Not wired to any view yet; covered by `tests/end-actions.test.js` and `tests/launcher-words.test.js`.
- Pure logic for the time journal and the favourites (`History.js`, NAK-400). Not wired to any view yet; covered by `tests/history.test.js`.
- History file store (`components/daemon/HistoryStore.qml`, NAK-432): one private file (0600 in a 0700 folder), written only when a timer ends, erasable, removable at uninstall. Not wired yet; covered by the offscreen test `tests/qml/run.sh`.
- Pure logic for known durations: the built-in table and the user's own durations (`KnownDurations.js`, NAK-429). Not wired to any view yet; covered by `tests/known-durations.test.js`.
- Pure logic for the notice before the end and the snooze choices (`components/daemon/Notice.js`, `components/daemon/Snooze.js`, NAK-430). Not wired to any view yet; covered by `tests/notice.test.js` and `tests/snooze.test.js`.
- `dms ipc call smartTimer status` prints the timers as JSON for scripts (remaining seconds, phase), built on call only (`components/daemon/Status.js`, NAK-431). Covered by `tests/status.test.js` and `tests/daemon-surface.test.js`.
- Anonymous diagnostics module: an in-memory log of codes and an allowlisted report, with no name, path or command line, written to nothing on disk (`diagnostics/`, NAK-471). Not wired to any view yet; covered by `tests/diagnostics.test.js`.
- Pure sections table and search index for the settings page (`components/settings/Sections.js` and `Search.js`, NAK-506). Not wired to any view yet; covered by `tests/settings-sections.test.js` and `tests/settings-search.test.js`.
- Design mockup and spec of the "Copy report" row in the settings Help section, with a GitHub mark that opens a new issue (`docs/design/copy-report.md` and `docs/design/copy-report/`, NAK-535). Design only: no code change.
- Design mockup of the "when a timer ends" row in Sands settings: three choices, greyed without Alex, narrow form (`docs/design/alex-row/index.html`, NAK-545). Design only: no code change.

### Changed

- Settings page: Sands' own switch and list rows (`components/settings/`) replace the DMS ones, so titles and descriptions wrap before the control and nothing is drawn under it at the narrowest real width (NAK-425). Saved keys, values and defaults are unchanged; `scripts/preview/settings-overlap.qml` fails on any overlap. A list row (Hourglass, Sound) now always puts its list under the title at full width, where DMS put a 200 px list beside the title on a wide page.

### Fixed

- No em dash in the timer-finished notification title and in the IPC replies: a plain hyphen with spaces instead (`components/daemon/Notifications.js`, `components/daemon/IpcReplies.js`, `components/daemon/PlainText.js`, NAK-556). The dash scan covers every `components/` file and the `list` reply. Covered by `tests/daemon-text.test.js`.

## 1.5.1 - 2026-10-09

### Changed

- The bar pill's final-countdown beat now ticks at 30 Hz instead of 60 Hz (the bell swing keeps 60 Hz): half the bar redraws during the last ten seconds, same beat. Offscreen bench, pill in its final countdown: 0.36 % → 0.21 % of one core (below the noise of this bench). Nothing animates while idle.

### Fixed

- 1.5.0 was published without the idle-timer change of NAK-194 (the pill's final-countdown beat stayed at 60 Hz). 1.5.1 ships it; the rest is documentation (launcher picture, test counts).

## 1.5.0 - 2026-10-09

### Added

- **A more natural launcher** (Win + Space), in English and French, nothing sent anywhere:
  - **Natural durations**: `timer 20m pâtes`, `timer 1h30 réunion`, context words kept in the name (`timer cooked 25m`), and a bare number after a word as minutes up to 180 (`pasta 12`). A bare number alone is never a timer. A unit one letter off is read (`20 mni`, `1 heur`, `20 minuts pasta`); names are never corrected, and real words (`3 jours`, `2 hors`) stay words.
  - **Natural clock times**: `wake me up at 7`, `réveille-moi à 7h`, `until 6pm`, `tonight at 9`, `ce soir à 9h`, `tomorrow at 8`, `demain 8h`, `noon`, `midi`, `minuit`, `7 du soir`, `7 in the morning`. A bare hour after `at` / `à` is the next occurrence within 24 h; `tomorrow` is the next calendar day. `8h` alone lists both readings (8 h timer, then 08:00) and nothing starts before Enter.
  - **One-line preview** under what you type: `Pasta · 12 min · ends 12:42`, `Wake up · at 07:00 tomorrow`, `Timer · 12 min · ends 12:42` (no name), with `Rings in/at …` below.
  - **Unknown words**: a timer keyword with nothing readable shows `Unknown word « … »` and Enter opens the guide.
  - Documented in the new guide sections *Natural phrases* and *What the launcher shows*, and in the README *Launcher syntax*. Per-keystroke cost of the parser: not measured.
  - Delivered in four parts: NAK-150 (durations), NAK-151 (clock times), NAK-152 (preview), NAK-153 (documentation).
- `sounds/` with the two rings (41 KB), and `tools/sounds/`, the script that renders Hourglass bit for bit (python3 and ffmpeg).
- Offscreen preview scenes in `scripts/preview/` (pill, panel, hourglass, four timers) rendered from made-up timers, with reference pictures and a compare script, so refactors can be proven pixel-identical. Development tooling only: the plugin loads nothing from it and nothing changes for users. See *Offscreen previews and bench* in `CONTRIBUTING.md`.

### Changed

- The panel code is split by role (hourglass and gestures, clock, controls, other timers, frost): no change in look or behavior, checked pixel for pixel against the offscreen references. The frost layers and the list of other timers are now built only while they are visible.
- Internal: `components/Hourglass.qml` (33 KB) is split into short single-role files in `components/hourglass/` (geometry and frost shapes in tested `.js`, one canvas per layer, the two Glass of Time layers loaded only in that style, one clock Timer). No visible change: all offscreen preview scenes match their references pixel for pixel, and no animation loop was added.
- Internal only: `TimerWidget.qml` (19 KB) is split by role into small files in `components/` (horizontal and vertical pill, glyph, name, time, badge, motion clock, hover, clicks). The pill scenes are byte-identical to their reference pictures (panel scenes within their tolerance), and the pill's timers and animations are unchanged (nothing runs at rest). See *Project layout* in `CONTRIBUTING.md`.
- The default alarm is now **Hourglass**, a soft four-note glass ring made for Sands, instead of the freedesktop alarm clock. **Silt Chime**, a short bell (CC0), is the second choice in *Sound*.
- The former default is now a normal entry in the list of installed sounds. A sound you picked yourself keeps playing; only an unset *Sound* (or the former "Alarm clock (default)") now plays Hourglass.
- A lighter download: the README and guide images weigh 1.62 MB instead of 1.97 MB (-18 %). PNGs are recompressed without any pixel change; the two animations (`freeze.gif`, `flip.gif`) use a light lossy GIF pass whose largest per-frame difference is invisible (worst frame 49.8 dB PSNR). Names, sizes, frame counts, delays and looping are unchanged.
- Internal: `TimerDaemon.qml` (27 KB) is split by role into `components/daemon/` (persistence, sounds, end notification, `dms ipc` commands) with its pure rules in tested `.js` files. Behaviour is unchanged: same IPC answers, alarm, notification and saved state, and nothing new runs at rest. A small test (`tests/daemon-surface.test.js`) checks that every daemon member the views read is still declared.

## 1.4.3 - 2026-10-03

### Changed

- When something can't be done, Sands says why in a short note at the top of the open panel (or a DMS toast when the panel is closed), with a GitHub mark that opens the matching section of the guide. The note fades after 4 seconds, and no timer runs while it is hidden.
  - `4x 1h` with fewer free places starts what fits and says *Started 2 of 4*.
  - An alarm that made no sound says *The alarm made no sound* and points to the new guide section *If the alarm makes no sound*.
  - A sound preview that fails says *Could not play this sound*.
- `dms ipc call smartTimer start` answers how many timers started (`Started: 10 of 20 × …`) and why none did (`Not started: …`).

### Fixed

- The alarm was silent with the default sound: the settings dropdown saved its label (`Default (alarm clock)`) instead of an empty value, and Sands tried to play a file by that name. Any value that is not a full path now plays the default alarm.

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
