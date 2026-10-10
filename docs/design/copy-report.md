# Sands · Copy report row (NAK-535, built in NAK-474)

Page to judge: `docs/design/copy-report/index.html` (one self-contained file, no network, no image). Switches: theme (stock, green, wallpaper-generated), light / dark, panel width (518 wide, 436 narrow, 360 stress), Reduce motion, clipboard tool present / missing, state shown in the panel. Every state is also drawn side by side under the panel, with live motion, contrast and copy tables.

Idea: the report is poured into the clipboard. On success a heap of sand settles at the foot of the button, the same heap as the rail marker (A · Dune, D446). Why it is not generic: no toast, no green tick, "done" reads as sand that has landed.

## Place

Help section of the settings with the left rail (NAK-502 / NAK-505), last row, after the examples, the command line and "Open the guide on GitHub". It uses Sands' own wrapping setting row (NAK-425). Nothing else in the section changes.

## Anatomy, sizes, tokens

| Part | Size | Token |
|---|---|---|
| Row | wrapping row, gaps 8 px (vertical) and 16 px (horizontal), centred vertically | none |
| Text block | flexible, wraps under 160 px | none |
| Title | `Theme.fontSizeMedium` (14), weight Medium, line 20 px | `Theme.surfaceText` |
| Help line | `Theme.fontSizeSmall` (12), line 16 px | `Theme.surfaceVariantText` |
| Button | 112 x 44 px, padding 16 px, radius `Theme.cornerRadius` (12), border 1 px, label 14 px centred | border `Theme.outline`, label `Theme.surfaceText`, no fill |
| Button hover fill | whole button | `Theme.surfaceContainerHigh` |
| Copied tint | whole button | `Theme.primary` at 14 % |
| Copied border, check (16 px, 1.5 px round stroke), heap (full width x 8 px at the foot) | | `Theme.primary` |
| Guided message | existing `HelpNote` look, full row width, padding 8 / 12 px, radius 12, gap 4 px | fill `Theme.surfaceContainerHighest`, border `Theme.withAlpha(Theme.outline, 0.24)`, title `Theme.surfaceText` Bold 14, hint `Theme.surfaceVariantText` 12 |
| GitHub mark | existing `GitHubMark` 18 px in a 44 x 44 target | `Theme.surfaceVariantText`, hover `Theme.primary` |

The button width is fixed (112 px) so it does not move when its label changes. Heap path on a 100 x 8 box, stretched to the button width: `M0 8V7C22 7 30 1 42 1S66 6 100 7V8Z`.

Layout, measured in WebKit: see the next section (the first version, without the mark, kept the button on the text line at 518 px).

## GitHub mark beside the button (D451, owner 2026-10-10, for every plugin)

The existing `GitHubMark` (18 px in a 44 x 44 target) is always visible, 8 px to the right of "Copy report", in every state. It opens the plugin's GitHub page where a problem is reported, in the browser, on click only (the plugin itself never touches the network).

| State | What is drawn |
|---|---|
| Rest | `Theme.surfaceVariantText` |
| Hover | `Theme.primary`, label "Open an issue on GitHub" 4 px under the controls |
| Focus-visible | 2 px `Theme.primary` ring, 2 px offset, same label |
| After "Copied" | `Theme.primary` while "Copied" is shown: the next step shows itself |

Label: 12 / 16 px, padding 4 / 8 px, radius 12, fill `Theme.surfaceContainerHigh`, text `Theme.surfaceText`, edge `Theme.withAlpha(Theme.outline, 0.24)`; it wraps and never leaves the column (use the DMS tooltip if it gives the same result).

Destination, proposed to the owner (not decided):
1. [recommended, drawn] new issue with the bug form: `github.com/lung595/<repo>/issues/new/choose`. The report is in the clipboard, the next gesture is paste. Needs a bug form with a "Paste the report" field in each repo (one small story per plugin). Not checked here: what GitHub shows at this address while a repo has no form.
2. list of issues: `github.com/lung595/<repo>/issues`. Nothing to add to the repos, one more click before pasting.

Layout change: button + mark are 164 px wide, so with the 160 px text block they no longer fit on one line in the 294 px column: at 518, 436 and 360 px the controls sit under the help line, left aligned, 8 px below (at 360 px the mark drops under the button). They return to the text's line from a 340 px column. The mark of the guided message keeps its own target (the guide section, D228).

Contrast: mark at rest = variant / surface (lowest 8.83), hover and after copy = primary / surface (lowest 6.08), label = text / high (lowest 9.47); all in the table below.

## States

| State | What is drawn |
|---|---|
| Rest | outline button "Copy report" |
| Hover | fill `surfaceContainerHigh` under the label |
| Pressed | hover fill, button at 97 % |
| Focus-visible | 2 px `Theme.primary` ring, 2 px offset |
| Collecting | label "Collecting…" in `surfaceVariantText`, presses ignored (never longer than about 2 s; skip the state if the report is built in the same frame) |
| Copied | primary border, 14 % primary tint, check + "Copied", heap at the foot; help line becomes "Report copied. Read it, then paste it in a GitHub issue."; back to rest alone after 4 s |
| No clipboard tool | button back to rest, guided message under the row; stays until the next press or until the section closes |
| Disabled, empty, error, loading | no disabled or empty form: the row is always available. Error = the guided message. Loading = Collecting |

Keyboard order: "Open the guide on GitHub", "Copy report", the GitHub mark beside it, then the mark of the message when it is shown. Enter and Space press the button. The help line and the message are announced (polite live region; in QML `Accessible.name` / `Accessible.description` updated with the state).

## Motion (kit durations, `OutCubic`, D449; exits never longer than entries)

| What | Property | Duration |
|---|---|---|
| Hover fill | opacity | 150 ms in, 100 ms out |
| Press | scale to 0.97 | 100 ms in, 100 ms out |
| Copied label and tint | opacity | 150 ms in, 100 ms out |
| Heap settles | scaleY 0.3 to 1, origin bottom | 200 ms in, 100 ms out |
| Guided message | opacity | 150 ms in, 100 ms out |
| GitHub mark colour, mark label | colour / opacity | 150 ms in, 100 ms out |
| Reduce motion (`SettingsData.reduceMotion`) | opacity only | 150 ms, nothing scales or settles |

All are one-shot `Behavior`s. Nothing moves at rest. The only `Timer` (4000 ms, single shot) runs while "Copied" is shown, as in `HelpNote`.

## Exact copy (English only, D87; no em dash)

| Part | Text |
|---|---|
| Title | Anonymous report |
| Help line | Versions, states and error codes only. It stays on this PC until you paste it. |
| Button | Copy report |
| Button while collecting | Collecting… |
| Button once copied | Copied |
| Help line once copied | Report copied. Read it, then paste it in a GitHub issue. |
| Guided message, reason | The report could not be copied |
| Guided message, what to do | Install wl-clipboard, or run dms ipc call smartTimer diagnostics in a terminal. |
| GitHub mark beside the button, accessible name | Open a new issue for Sands on GitHub |
| GitHub mark beside the button, label on hover or focus | Open an issue on GitHub |
| GitHub mark in the guided message, accessible name | Open the guide: Report a problem |

## Contrast (WCAG formula, tints composited on `surface`; same six palettes as NAK-502)

| Pair | Need | stock dark | stock light | green dark | green light | wall dark | wall light |
|---|---|---|---|---|---|---|---|
| title, button label (text) / surface | 4.5:1 | 12.57 | 16.23 | 12.70 | 16.29 | 12.73 | 16.29 |
| help line, "Collecting…" (variant) / surface | 4.5:1 | 9.56 | 8.88 | 9.57 | 8.87 | 9.65 | 8.83 |
| button label, note title (text) / high | 4.5:1 | 9.47 | 13.17 | 9.58 | 13.25 | 9.58 | 13.30 |
| note hint (variant) / high | 4.5:1 | 7.20 | 7.21 | 7.22 | 7.21 | 7.27 | 7.21 |
| "Copied" (text) / primary tint | 4.5:1 | 9.15 | 13.31 | 9.25 | 13.37 | 9.28 | 13.34 |
| check, heap (primary) / primary tint | 3:1 | 6.96 | 5.02 | 6.99 | 4.99 | 7.03 | 5.02 |
| button outline / surface | 3:1 | 5.14 | 4.33 | 5.18 | 4.28 | 5.17 | 4.24 |
| copied border, focus ring (primary) / surface | 3:1 | 9.56 | 6.12 | 9.59 | 6.08 | 9.64 | 6.13 |
| GitHub mark (variant) / high | 3:1 | 7.20 | 7.21 | 7.22 | 7.21 | 7.27 | 7.21 |
| GitHub mark hover (primary) / high | 3:1 | 7.20 | 4.97 | 7.23 | 4.94 | 7.26 | 5.00 |

No failure. The page recomputes this table live for the palette shown. The page draws the note fill with the palette's `high` value (the NAK-502 palettes have no separate `surfaceContainerHighest`); on a real theme `HelpNote` uses `surfaceContainerHighest`, to be re-measured on the build.

## What the engineer builds in NAK-474

1. One component for the row (for example `components/settings/ReportRow.qml`), added as the last row of Help; the button, the label swap and the heap in it or in one small button component. Colours from `Theme` only.
2. The report is collected on press only; nothing runs before. Copy with `wl-copy --sensitive`, data on standard input, never on the command line.
3. Result states `rest`, `collecting`, `copied`, `none` in pure JS (as Orbit `Guide.reportNote`), tested with gjs.
4. The guided message reuses `HelpNote` and `GitHubMark`. `HelpNote` hides itself after 4 s today: here it must stay until the next press (a property that turns its timer off), because the hint holds a command to read and type.
5. Offscreen test: no overlap of title, help line, button, message and mark at 518, 436 and 360 px, in every state.
6. Model, read only: orbitBluetooth 1.14.0 `components/settings/ReportRow.qml`.

## Assumptions (conservative, not asked)

- The command line call is `dms ipc call smartTimer diagnostics` and the guide anchor is `report-a-problem`, as in Orbit. NAK-474 owns the real names; the copy follows them.
- No clipboard-history sentence (Orbit adds one when DMS history is on): `--sensitive` keeps the report out of the history. If NAK-474 finds it is kept, add Orbit's sentence to the copied help line.
- Battery pill (D419): none. The row costs nothing until pressed, so a pill would be decorative.

## Verification

Done, offscreen in WebKitGTK 6.0 through gjs (`gjs tools/check.js "$PWD/index.html"` from `docs/design/copy-report/`): 3 themes x light / dark x 3 widths x 9 states (7 of the button, hover and focus of the mark), panel and state sheet each time = 162 cases. 0 console error, 0 overlap, 0 overflow, 0 clipped text, button 112 x 44 and mark target 44 x 44 everywhere, 0 contrast failure, no em or en dash, no URL / src / href / import. One real-size render looked at in dark (436 px, panel and the 9 states).

Not done: HiDPI render; the live press sequence and its transitions were not watched (the offscreen view has no frame clock), only its end states; Reduce motion checked by reading the CSS, not measured.
