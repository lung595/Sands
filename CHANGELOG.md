# Changelog

All notable changes to Sands are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## 1.7.1 - 2026-11-26

### Fixed

- **Each ring leaked a process when `notify-send` is missing.** A helper that never starts sends neither *started* nor *exited*, so the notification `Process` was never freed; it now is.
- Two tests could not fail: the motion checks passed on `NaN`, and the `markNotified` check never tried a list that already held the id.

### Changed

- A cleanup pass over the whole repository, with no change to behaviour or looks: unused code, ids, options and helpers removed (about 650 lines fewer), the tests share the harness helpers instead of their own copies, and comments and docs brought up to date.

## 1.7.0 - 2026-11-20

### Added

- Settings, *Alerts & sounds*: **Ring after sleep**, a list of the choices Never, 1, 5, 15 and 60 min, default 5 (`wakeRingMinutes`). Found by searching "sleep" or "veille". Covered by `tests/qml-page/tst_alertRows.qml` and `tests/settings-search.test.js`.
- The *Timers* row of Spotlight (Super+Space), logic and wiring: `"launcherSection": true` in `plugin.json` (DMS floor unchanged; a DMS without live launcher sections ignores it and nothing changes) and `getSectionItems(query)` in `TimerLauncher.qml` with its header (« Minuteurs » / « Timers » by the DMS language, Material `timer` icon, « Minuteurs · N » once timers are hidden), priority 1.5 and a first card. The pure rules are in `components/launcher/Section.js`: ringing, then running by nearest end, then paused, then favourites; 4 places then a « +N » card counting only the hidden timers (it opens the 5th); favourites fill the free places, at most 3, never one already running; the ringing card takes the selection with an empty query only; the order only changes when a timer appears, disappears or changes state. The daemon asks DMS to refresh the row on `timersChanged` (never from the clock), and only once DMS has called `getSectionItems`: every DMS declares `requestLauncherUpdate`, and one without live sections would run the open search again, so there it is never fired; favourites are read from the history after a change, never per query. Without the timer service the row stays hidden and `SND-W012` is written once, which `scripts/diagnose.sh` prints on its own line. New settings section **Launcher**: Timers in the launcher, While searching, Favourites in the row, Animate the sand (all on, found by the search in English and French, reported in the diagnostic report). Covered by `tests/launcher-section.test.js`, `tests/qml-page/tst_launcherSection.qml`, a fourth check of `tests/qml-daemon` (no refresh before the row is asked for, then one per list change), `tests/diagnose.test.sh` and the settings tests.
- The cards of the *Timers* row of Spotlight (`components/launcher/`). Collapsed: a small hourglass of the panel (no halo, no shadow, no frost), « Pâtes — 12:34 » in tabular digits, then the end time (DMS 12/24 h setting) or a pause icon; a favourite is a full, still hourglass with its duration, dimmed, and Enter starts it; « +N » opens the 5th timer. Ringing: an empty top bulb, the overrun « +0:42 » in red, one soft pulse, a stop button (Enter stops, a click opens). Open (Enter or a click): a large hourglass, the name and time, icons for the end, the duration, the notice and the sound (a click mutes or unmutes the timer), round icon buttons pause / restart / stop, −1 / +1 / +5 chips, or when ringing stop, three snooze chips (the last used first) and restart; the name is renamed by a click or F2 (Enter or a click elsewhere keeps it, Esc cancels, emoji dropped, an empty name refused); « Autres minuteurs » lists the other timers as mini-cards, a click opens one. A stopped timer stays in place for 5 s as « Stopped · Undo » (Enter undoes); if the launcher closes first, a DMS toast shows `dms ipc call smartTimer undo`. Keys from the search field: Tab enters the controls, Space pauses only from the controls, Esc stays DMS's. Every control has a tooltip and a name for screen readers; chips can now take the keyboard focus. The open card grows with a small spring overshoot, the hourglass turns over on a restart and on added time, and the sand flows while the launcher shows; Reduce motion or *Animate the sand* off freezes it all and stops the hourglass clock. Covered by `tests/launcher-card.test.js` and `tests/qml-page/tst_launcherCard.qml`; preview `scripts/preview/launcher-section.qml` (was `launcher-section-shot.qml`) with variants.
- `Strings.js`, the groundwork of a French and English interface, not wired in the views yet: every sentence of the pure modules under one key in an English and a French table, `tr(key, lang, ...args)` with `%1` templates and an English fallback, and `langOf(locale)` (`fr_FR`, `fr-CA` → French; anything else → English), the language DMS uses. `Preview`, `Guide`, `Commands` (its preview words leave `lang/*.js`), `KnownDurations`, `Retired`, `Notifications` and `IpcReplies` read their words from it and take the language as an optional last argument, so the English they give today is unchanged. Covered by `tests/strings.test.js` (same keys and placeholders in both languages, no emoji, every key asked for exists) and French cases in the module tests.
- Natural language: fractions of an hour (`dans 1/4 d'heure`, `1/2 h`, `3/4 of an hour`), approximations dropped next to the time (`dans 1h à peu près`, `about 20 min`, `20 min-ish`, `environ`), `6:15 p.m.`, punctuation trimmed from the ends of a name (`Timer: 10 min, pâtes !` is *pâtes*) and emoji removed from it. `TimeParser.parse()` is now a list of named stages, and its words live in the language packs `lang/en.js` and `lang/fr.js`, whose union builds the regexes. `dans 1/2 heure` no longer reads as two hours. Covered by `tests/parser.test.js`, which also runs its cases with each pack alone.
- Known durations for a name typed without a number, not wired yet: `KnownDurations.suggest("timer pâtes", { recents, history, entries, lang })` gives `{ ms, source, name, icon, text }`, « Pâtes — 10 min (durée habituelle) » / « Pasta — 10 min (usual time) ». The user's latest duration for that name (the recents, which hold what the user typed, else the history, a snooze record never counting) comes first (`source: "mine"`), then their own entries, then the built-in table (`"table"`). Accents, case, emoji and plurals (« pâte », « oeufs durs ») are ignored; the trigger word sets the language when none is given. Covered by `tests/known-durations.test.js`.
- `Commands.js`, the launcher commands on running timers, not wired yet: `parseCommand` (`timer +5`, `timer -2 pâtes`, `pâtes +1h30`, `pause pâtes`, `reprendre`, `resume tea`, `snooze 10`, `renomme pâtes en riz`, `rename tea to infusion`, `thé = infusion`), `resolveTarget` (no name: the ringing timer, else the one ending first; a name: that one) and `previewCommand` (« +5 min à Pâtes (finit à 18:47) », with the 10 s floor). Covered by `tests/commands.test.js`.
- Daemon calls for the launcher card: `pauseAll` / `resumeAll` (one save for every timer; `dms ipc call smartTimer pause` and `resume` use them), `rename(id, name)` (emoji dropped, cut to 60 characters, an empty name refused), `toggleMute(id)` (saved with the timer: a muted timer still rings with its dune and notification, without sound; with the alert set to "only when muted", its dune shows), and `undoRemove(id)`: a stopped timer that was running or paused can be brought back for 5 s, also with the new `dms ipc call smartTimer undo`. The `timersChanged` signal of the timer list (only on a change, never from the clock) and `removedChanged` are the launcher's cues. `Timers.stripEmoji` / `cleanName` remove emoji from a name (a name of emoji only becomes « Minuteur » / « Timer »). Covered by `tests/lifecycle.test.js`, `tests/timers.test.js`, `tests/daemon-text.test.js` and a third run of `tests/qml-daemon` (muted ring, rename, undo within and after 5 s, pause all, one list change per action).
- Settings: a **Getting started** section, first in the rail, as in Orbit. It says the widget must be in a bar to see any timer (a red-edged callout, or a check once a bar holds Sands), then four steps: add the widget, start a timer, watch the pill, click it; and a button to the full guide. The page opens on it while the widget is in no bar (`components/settings/Placement.js`, read only from `SettingsData.barConfigs`), else on Timers. Search finds it under « add widget », « tutorial », « ajouter barre »… The README now names DMS 2.x's **Bar widgets** page. Covered by `tests/settings-sections.test.js`, `tests/settings-search.test.js` and `tests/qml-page/tst_sections.qml`.
- Diagnostics wiring: `dms ipc call smartTimer diagnostics` (report on request, CPU measured only then), the "Copy report" row in Help (`wl-copy --sensitive` through stdin, fallback `dms clipboard copy`, guided message when neither exists) with a GitHub mark that opens a new issue on click only (constant address, nothing prefilled), `scripts/diagnose.sh`, the `bug.yml` issue form, and event codes logged on a failed ring sound, a failed notification helper, unreadable saved timers and an unparsed IPC text. Covered by `tests/report-row.test.js`, `tests/diagnose.test.sh`, `tests/qml-page/tst_copyReportMark.qml`, `tests/qml/tst_reportCopy.qml` (fake `wl-copy` and `dms` on PATH: text on standard input and never in the arguments, fallback, one hand-over) and the overlap scene (copied, guided message and mark label states). The guided message reuses `HelpNote`, now keyboard reachable. After review: a tool that hangs is stopped after 4 s, an unreadable CPU file no longer blocks the report, the row says when the report was left in the DMS clipboard history, the login and the folders under `/run/media` are hidden, a `key = value` secret is hidden in `scripts/diagnose.sh`, the picture scale mark rule (`icon@2x.png`) is limited to picture extensions, and `scripts/preview/report.qml` is the bench scene of the report service (idle and collecting). Second review: the journal is read with `-o cat` and a line that still has its prefix loses it whatever the language of the date (French and Japanese dates tested), `scripts/diagnose.sh` applies the rules of `diagnostics/Redact.js` in the same order, a host name of two characters is hidden as a whole word, a press on the button during an IPC collection gets that report copied too, and a later press no longer clears the report that waits for the IPC call.
- Settings, *Alerts & sounds*: "Show on" chooses which screen shows the visual alert, dune and halo alike, also for "Test the alarm": All screens (default, as before), Active screen (the one with the focus when the timer ends, asked from the DMS `CompositorService`) or one screen by name. Saved as `alertScreen` (`all`, `focused` or an output name such as `DP-2`); a screen that is unplugged, or a focus the compositor does not report, gives all screens, never none (`AlertPolicy.screensFor`). Found by the search ("screen", "monitor", "écran"). Covered by `tests/alert-policy.test.js` and `tests/qml-page/tst_alertRows.qml`; the layer-shell windows themselves are not covered by a test.
- Settings, *Alerts & sounds*: the visual alert can be chosen. Three cards for the kind (Rising dune, Edge halo, None; Edge halo is greyed with a note and the GitHub mark to the guide when the session has no layer shell), one card per Rising dune style (Last grains, Wind dune, Flat wave), a "Show above full screen" switch for the dune, "Show the visual alert" (Every time, the default, or When sound is off) and a "Test the alarm" button that plays the sound and asks the daemon for one test alert (fake name "Pasta", stops by itself or on a click). The rows save the keys the daemon already read (`alertKind`, `duneStyle`, `duneOverFullscreen`, `alertWhen`), and `RingAlert` reads them again when the plugin data changes, so a choice applies to the next ring. All five rows are found by the search. Covered by `tests/qml-page/tst_alertRows.qml`, `tests/dune-styles.test.js`, `tests/settings-search.test.js` and `tests/settings-sections.test.js`; the layer-shell windows themselves are not covered by a test.
- Settings: an Erase history button.
- Pinned favourites in the panel: the three named timers started at least twice and most often, as "Three glasses" tiles (default) or "Rows", one click or Enter starts one again with the same name and duration; read from the journal when the panel opens only, one `Loader` for the look, the glass turns once (300 ms, none with Reduce motion). The look follows `Variants.js`; the settings rows come later. `History.favourites` also returns the duration of the latest start. A start the daemon refuses is not shown as started; the preview scene is `scripts/preview/favourites-shot.qml`. Covered by `tests/pins.test.js` and `tests/qml-page/tst_favourites.qml`.
- Settings page with a left section rail (option A "Dune"): Timers, Appearance, Alerts & sounds and Help (the launcher examples and the command line moved there from Timers), one section shown at a time, all built with the page, a search bar on top (names, help, synonyms in English and French, typos forgiven; Enter opens the first hit, Esc clears, Ctrl+F or / focuses) that opens the found setting's section and fades a highlight over its row once (150 ms with Reduce motion). The rail becomes a stack under 400 px. Saved keys, values and defaults unchanged. Section logos are drawn as stroked shapes in the theme colour. Not yet: the settings still pending. A pick whose row is hidden by the current state (Prefix, Sound file) highlights the row it depends on, and "Examples and commands" highlights the Help block; the page scrolls the found row into view when it sits in a flickable; Esc only clears a non-empty query and Ctrl+F and / are window shortcuts active while the Sands page is shown (/ is ignored while a text field has the focus). `scripts/preview/rail-scenes.sh` renders the scenes (default, result, no result, narrow, light, dark, Reduce motion).
- Pure logic for the visual alert (`components/alert/AlertPolicy.js`, `HaloMotion.js`): which alert to draw (dune, Edge halo, none) and when (when the sound is off, or every time; hidden over full screen unless allowed), and the finite steps of the Edge halo (rise, 3 beats at 30 Hz, rest; Reduce motion shows the posed rim only). Covered by `tests/alert-policy.test.js` and `tests/halo-motion.test.js`.
- The time journal in the panel: a "This week" screen with the week's time per name, as Strata layers in a glass (default) or Threads bars, one `Loader` so only the chosen look exists, read from the daemon only when the screen opens. Pure logic in `components/journal/Journal.js`, covered by `tests/journal.test.js` and the offscreen layout test `tests/journal-layout.sh` (empty, one, many and very long names, narrow and wide, light and dark, Reduce motion).
- Edge halo scene and alert host (`components/alert/HaloScene.qml`, `DuneAlert.qml`): a 4 px primary rim in 200 ms, 3 beats, then still until dismissed, on every screen through layer shell; the host reads the kind and moment through `AlertPolicy`, holds one scene in a `Loader` that exists only while the alert shows, and offers `ring()`, `dismiss()` and `test()` (fake name "Pasta"). Covered by `tests/qml/run.sh` and `tests/halo-contrast.test.js` (legend contrast 9.5:1 or more on every stock theme).
- Rising dune, style "Wind dune" (`components/alert/WindScene.qml`): the same matte sand as Last grains, blown in from the left edge with a travelling crest and grains that hop on the sand, a 1 px lit edge on the windward slope once settled, hard stop at 2.6 s; the legend shows once sand is behind all of it. Drawn for the saved value `wind`; a style picked while the alert shows starts its own run. `scripts/preview/dune.qml` takes `style=`. Covered by `tests/dune-motion.test.js` and `tests/qml-dune/run.sh` (each style loads its own scene, ends by itself, then no repaint; Reduce motion; 360 px).
- Rising dune, style "Flat wave" (`components/alert/WaveScene.qml`): one flat ridge in the primary colour that springs up past its height and thuds three times, with a rim along the crest, a base line, sand specks, eight round grains and fine sand thrown at each thud, hard stop at 2.4 s; the rim tint is raised until it reaches 3:1 against the primary (`SandTint.cel`). Drawn for the saved value `wave`. Covered by `tests/sand-tint.test.js` and `tests/qml-dune/run.sh`.
- Rising dune scene, default "Last grains", and the wiring of the alert host to the timer engine (`components/alert/RingAlert.qml`, `DuneWindows.qml`, `DuneBand.qml`, `GrainsScene.qml`, `SandTint.js`): when a timer rings, every time by default (the saved moment can limit it to when the sound cannot be heard), a 200 px band of sand rises along the bottom edge of every screen with the name of the timer, a click on the legend stops the ring, and nothing exists at rest. Several timers ending together share one dune named after the last one. Covered by `tests/sand-tint.test.js`, `tests/alert-policy.test.js` and `tests/qml-dune/run.sh`.
- The daemon raises a `noticeDue(id)` signal once per timer shortly before it ends (`components/daemon/NoticeRunner.qml`): one single-shot wake-up armed at `Notice.nextDueAt`, re-armed only when the timer list changes (the `noticeMinutes` setting is read then), nothing armed without an eligible timer. Default 2 min, 0 turns it off, silent; nothing is shown yet. Covered by `tests/qml/run.sh`.
- Pure logic for the three look choices (`components/settings/Variants.js`): the journal, favourites and notice looks, with their keys, allowed values, defaults, English labels and `clean(key, value)`. Covered by `tests/variants.test.js`.
- The daemon keeps each timer that rings in the private history (`HistoryStore`): one record at the ring through `History.js`, nothing while a timer runs or at rest; stopped timers are not kept. Read side on demand only (`historyThisWeek`, `historyFavourites`), `eraseHistory`, and the file and its folder are removed when the plugin is uninstalled (`HistorySweep`, a detached removal once the manifest is gone). Covered by `tests/qml/run.sh` and `tests/history.test.js`.
- "Rising dune" motion model: three sand styles (`grains` default, `wind`, `wave`) with a fallback for unknown values, seeded 30 Hz steps that end by themselves, and the full-screen rule. Approved mockup in `docs/design/rising-dune/`.

### Changed

- The formatting functions (`formatClock`, `formatHuman`, `formatRelative`, `formatTimeOfDay`, `isTomorrow`, `widthTemplate`) moved from `TimeParser.js` to `TimeFormat.js`, which also gets `use24h(setting)` for the DMS 12/24 h choice; `TimeParser.js` re-exports them for now, so nothing changes for its callers. `Plans.js` uses the parser's `normalize` instead of its own copy. Covered by `tests/time-format.test.js`.
- The offscreen renders are no longer in git: `out/` is ignored, and `scripts/preview/shots.sh` writes there by default from any folder. Covered by `tests/preview-out.test.sh`.
- Taking time off a timer stops at 0:10 instead of being refused below one second: « pasta −5 » with 3 min left gives 0:10, and the −1 min button and the panel wheel work until 0:10.
- Docs: README and GUIDE share one *Privacy* list naming every program Sands starts, checked against the code by `tests/docs-privacy.test.js`; the launcher *Timers* row, its settings and its DMS requirement are documented.

### Fixed

- A timer that rang long before was written again to the journal and notified again each time another one ended, when its notification had been closed or notifications were off. The engine now names the timers that have just rung (`Lifecycle.expire` gives their ids) and only those are journaled and notified. Covered by `tests/lifecycle.test.js`.
- A second timer ending while the first one rang raised no dune. The daemon now emits `rang(ids)` for each new ring and the dune (or the halo) rises again with the latest name; the end of the ring still takes it down. Covered by `tests/qml/tst_haloAlert.qml` and `tests/qml-daemon/run.sh`.
- A timer that ended during sleep or while the shell was off follows one rule, at startup and on wake (`Lifecycle.settle`): if it ended less than *Ring after sleep* ago it rings as usual, otherwise it gets no sound and no dune, only a notification ("Pasta finished at 02:14") and its journal line; it stays in the list as done. Before, such a timer stayed ringing silently and was never written to the journal. The state is saved as soon as a restart finds one ended, so a second restart neither journals nor announces it again. Covered by `tests/lifecycle.test.js` (an 8 h jump) and `tests/qml-daemon/run.sh`.
- A timer named in lower case (« thé », from the IPC or the panel) showed « thé — 3:35 » on its Spotlight card while the rows under it wrote « Thé · 4 min ». A timer's name is now shown with a first capital everywhere it is written (`Timers.displayLabel`: cards, bar, panel, notifications, `list`, status), and a favourite card does the same. The history still keeps the name as typed (`Timers.savedName`), so a « thé » saved before and after this stays one favourite and one line in the week. Covered by `tests/timers.test.js`, `tests/history.test.js`, `tests/launcher-section.test.js` and `tests/launcher-card.test.js`; the `four` variant of `scripts/preview/launcher-section.qml` now types its names in lower case.
- The manual install cloned into a folder DMS does not read (the old shell folder, named after the display name): the README and CONTRIBUTING now clone into `~/.config/dms/plugins/smartTimer`, the folder named after the plugin id. `tests/docs-paths.test.js` fails on any other plugin install path in the docs and the scripts.
- Quickshell crashed when the settings page switched to "Alerts & sounds". The page no longer builds a section on demand: all five are built with the page and only shown or hidden, as before the rail. Cause not proven (a `Loader` with a deferred Popup is suspected); covered by `tests/qml-page/tst_sections.qml`.

### Removed

- The Alex integration: Sands no longer publishes a `timerFinished` event when a timer ends (added in 1.6.0) and no longer reads or changes the end mode of another plugin. A timer always ends the same way: sound, visual alert and notification, each as its own switch in *Alerts & sounds* says. The end-of-timer mode is gone from the look choices; an `endMode` or `timerEndMode` key saved by an older Sands is dropped silently at start (`components/daemon/Retired.js`), so the default applies. The 1.6.0 mockup in `docs/design/alex-row/` goes too. Covered by `tests/retired.test.js`, `tests/variants.test.js` and `tests/qml-daemon/run.sh`.
- The end actions and their launcher words (Power off, Sleep, Stop the music, your own commands, « 45m film off »): nothing ever ran them, so they go instead of staying a promise. `EndActions.js`, `LauncherWords.js` and their rows in *Timers* are gone, and nothing replaces them: the search no longer finds them. At the first start of 1.7.0 the saved `personalActions` and `actionWords` keys are erased, a saved timer that carried an end action ends as any other, and one toast, « End actions removed » (« Actions de fin retirées » in French), says so only if you had some; it never shows again (`endActionsRetired` in the plugin state). Covered by `tests/retired.test.js`, `tests/settings-search.test.js`, `tests/settings-sections.test.js` and `tests/qml-daemon/run.sh`.

## 1.6.0 - 2026-10-11

### Added

- `dms ipc call smartTimer snooze <minutes>`: restarts the first ringing timer for 1 to 120 minutes (0: 5 minutes, like the notification button; out-of-range values are clamped). Always answers JSON, `{"snoozed":false,...}` when nothing rings, with no state change. `Snooze.forIpc`, covered by `tests/snooze.test.js`.
- One "timer finished" event for Alex at the ring (`AlexBridge.js`): published once per ended timer through `PluginService.setGlobalVar` (key `timerFinished`, fields `kind: "timerFinished"`, id, label capped at 60 characters, end time) and only when Alex is loaded; without Alex nothing is called and nothing changes. Sands keeps showing its own alarm, sound and bar pill. Several timers ending in the same tick write the key once each (a late reader sees the last). Covered by `tests/alex-bridge.test.js`.
- Pure parser for focus-cycle and chained-timer phrases (`Plans.js`). Not wired to any view yet; covered by `tests/plans.test.js`.
- Pure logic for the end-of-timer actions and the free launcher words (`EndActions.js`, `LauncherWords.js`). Never wired, removed in the next version; covered by `tests/end-actions.test.js` and `tests/launcher-words.test.js`.
- Pure logic for the time journal and the favourites (`History.js`). Not wired to any view in this version; covered by `tests/history.test.js`.
- History file store (`components/daemon/HistoryStore.qml`): one private file (0600 in a 0700 folder), written only when a timer ends, erasable, removable at uninstall. Not wired in this version; covered by the offscreen test `tests/qml/run.sh`.
- Pure logic for known durations: the built-in table and the user's own durations (`KnownDurations.js`). Not wired to any view yet; covered by `tests/known-durations.test.js`.
- Pure logic for the notice before the end and the snooze choices (`components/daemon/Notice.js`, `components/daemon/Snooze.js`). Not wired to any view in this version; covered by `tests/notice.test.js` and `tests/snooze.test.js`.
- `dms ipc call smartTimer status` prints the timers as JSON for scripts (remaining seconds, phase), built on call only (`components/daemon/Status.js`). Covered by `tests/status.test.js` and `tests/daemon-surface.test.js`.
- Anonymous diagnostics module: an in-memory log of codes and an allowlisted report, with no name, path or command line, written to nothing on disk (`diagnostics/`). Not wired to any view in this version; covered by `tests/diagnostics.test.js`.
- Pure sections table and search index for the settings page (`components/settings/Sections.js` and `Search.js`). Not wired to any view in this version; covered by `tests/settings-sections.test.js` and `tests/settings-search.test.js`.
- Design mockup and spec of the "Copy report" row in the settings Help section, with a GitHub mark that opens a new issue (`docs/design/copy-report.md` and `docs/design/copy-report/`). Design only: no code change.
- Design mockup of the "when a timer ends" row in Sands settings: three choices, greyed without Alex, narrow form (`docs/design/alex-row/index.html`). Design only: no code change.

### Changed

- Settings page: Sands' own switch and list rows (`components/settings/`) replace the DMS ones, so titles and descriptions wrap before the control and nothing is drawn under it at the narrowest real width. Saved keys, values and defaults are unchanged; `scripts/preview/settings-overlap.qml` fails on any overlap. A list row (Hourglass, Sound) now always puts its list under the title at full width, where DMS put a 200 px list beside the title on a wide page.

### Fixed

- No em dash in the timer-finished notification title and in the IPC replies: a plain hyphen with spaces instead (`components/daemon/Notifications.js`, `components/daemon/IpcReplies.js`, `components/daemon/PlainText.js`). The dash scan covers every `components/` file and the `list` reply. Covered by `tests/daemon-text.test.js`.

## 1.5.1 - 2026-10-09

### Changed

- The bar pill's final-countdown beat now ticks at 30 Hz instead of 60 Hz (the bell swing keeps 60 Hz): half the bar redraws during the last ten seconds, same beat. Offscreen bench, pill in its final countdown: 0.36 % → 0.21 % of one core (below the noise of this bench). Nothing animates while idle.

### Fixed

- 1.5.0 was published without the idle-timer change (the pill's final-countdown beat stayed at 60 Hz). 1.5.1 ships it; the rest is documentation (launcher picture, test counts).

## 1.5.0 - 2026-10-09

### Added

- **A more natural launcher** (Win + Space), in English and French, nothing sent anywhere:
  - **Natural durations**: `timer 20m pâtes`, `timer 1h30 réunion`, context words kept in the name (`timer cooked 25m`), and a bare number after a word as minutes up to 180 (`pasta 12`). A bare number alone is never a timer. A unit one letter off is read (`20 mni`, `1 heur`, `20 minuts pasta`); names are never corrected, and real words (`3 jours`, `2 hors`) stay words.
  - **Natural clock times**: `wake me up at 7`, `réveille-moi à 7h`, `until 6pm`, `tonight at 9`, `ce soir à 9h`, `tomorrow at 8`, `demain 8h`, `noon`, `midi`, `minuit`, `7 du soir`, `7 in the morning`. A bare hour after `at` / `à` is the next occurrence within 24 h; `tomorrow` is the next calendar day. `8h` alone lists both readings (8 h timer, then 08:00) and nothing starts before Enter.
  - **One-line preview** under what you type: `Pasta · 12 min · ends 12:42`, `Wake up · at 07:00 tomorrow`, `Timer · 12 min · ends 12:42` (no name), with `Rings in/at …` below.
  - **Unknown words**: a timer keyword with nothing readable shows `Unknown word « … »` and Enter opens the guide.
  - Documented in the new guide sections *Natural phrases* and *What the launcher shows*, and in the README *Launcher syntax*. Per-keystroke cost of the parser: not measured.
  - Delivered in four parts: durations, clock times, preview and documentation.
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
