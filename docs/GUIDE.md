# Sands: user guide

Everything Sands can do, in detail. To install it and add the widget, see the [README](../README.md#getting-started).

## Contents

- [Use cases](#use-cases)
- [The bar pill](#the-bar-pill)
- [The hourglass panel](#the-hourglass-panel)
- [The launcher](#the-launcher)
- [Syntax](#syntax)
- [Settings](#settings) · [Sound](#sound) · [If the alarm makes no sound](#if-the-alarm-makes-no-sound)
- [Privacy](#privacy)
- [Performance](#performance)

## Use cases

| When you… | Type |
| --- | --- |
| boil pasta, steep tea, bake | `timer 11 min pasta`, `4m tea`, `45 min oven` |
| focus in blocks | `25m focus`, then `5m break` from the recents |
| need to leave at a given time | `at 18:30 train`, `timer 7am wake up` |
| run several things at once | start as many as you want: each gets its own color |
| cook with the laundry going | `1h laundry` + `12m pasta`: the pill shows the next one, `+1` for the rest |
| want a timer without the mouse | bind a key to open the launcher pre-filled with `timer ` |

## The bar pill

| | |
| --- | --- |
| ![running](images/pill.png) | **Running**: a ring drains, digits never jitter (tabular figures, fixed width). `+1` means another timer is running. |
| ![label](images/pill-label.png) | **Name on demand**: shown for two seconds when a timer starts, and whenever you hover. Hovering never opens anything. |
| ![done](images/pill-done.png) | **Done**: the pill grows red and breathes, the alarm loops, a notification offers *Stop* and *+5 min*. |

The ring turns amber during the last minute and beats during the last ten seconds.

| Gesture on the pill | Action |
| --- | --- |
| Left click | Open the panel (silences the alarm) |
| Right click | Pause / resume, or stop the alarm |
| Scroll | ±1 minute (scroll up on a finished timer = snooze 1 min) |
| Middle click | Cancel |

## The hourglass panel

<table>
<tr>
<td align="center"><img src="images/hero.png" width="300" alt="Running"><br><b>Running</b></td>
<td align="center"><img src="images/frozen.png" width="300" alt="Paused, frozen"><br><b>Paused, frozen</b></td>
</tr>
<tr>
<td align="center"><img src="images/ringing.png" width="300" alt="Done"><br><b>Done</b></td>
<td align="center"><img src="images/tea.png" width="300" alt="Every timer has its color"><br><b>Every timer has its color</b></td>
</tr>
</table>

- **A floating hourglass.** It levitates, tilts and casts a breathing shadow.
- **Sand synced by volume.** The bulbs' profile is integrated, so at half time exactly half the sand is left on top.
- **Freeze on pause.** Time slows to a stop, grains hang mid-air, frost settles on the glass, the digits turn ice-blue. It thaws just as smoothly.
- **Flip to restart.** The restart button turns the hourglass over and starts again.
- **A click is just for fun.** Click the hourglass: it spins twice and hops. Nothing about your timer changes, so you can never restart one by accident (with *Reduce motion*, it stays still).
- **Colors follow your theme.** The first timer uses your accent color; each additional timer gets a harmonious hue derived from it. Alerts use the theme's warning (last minute) and error (done) colors.

| Gesture on the hourglass | Action |
| --- | --- |
| Click | A spin and hop, just for fun (the timer is untouched) |
| Scroll | ±1 minute |
| Swipe / horizontal scroll | Next or previous timer (dots show where you are) |
| <kbd>Space</kbd> / <kbd>Esc</kbd> | Pause–resume / close |
| Restart button (↻) | Turns the hourglass over and starts again |

**Two hourglasses.** The classic one, or **Glass of Time**, a nod to *Steven Universe*: the glass floats in a cyan sphere with a gold ring around its waist. Only the frame changes.

![Glass of Time, running and frozen](images/glass-of-time.png)

## The launcher

![launcher](images/launcher.png)

No prefix needed: Sands only answers when what you type looks like a duration, and stays silent otherwise. Type `timer` alone to get your most used timers first (frequent *and* recent), then 5, 10 and 25 min, then the running ones.

**Cancel from the keyboard**: type `timer stop` (or `stop timer`, `cancel timer`). With one timer, <kbd>Enter</kbd> cancels it; with several, you pick which one, or *Cancel all*. Anything else you type with `stop` in it is left alone.

## Syntax

Type in English or French, words or digits, in any order:

| Input | Result |
| --- | --- |
| `20 min`, `20m`, `timer 20` | 20 minutes |
| `1h30`, `1h 30`, `1.5h`, `1,5 h`, `90 min` | 1 hour 30 |
| `1h30m20s`, `5m30`, `90s`, `1:30`, `1:02:03` | Exact durations (`1:30` = 1 min 30 s) |
| `half an hour`, `an hour and a half`, `twenty five minutes` | Spelled-out durations |
| `une demi-heure`, `trois quarts d'heure`, `2 heures et quart` | Same in French |
| `12 min pasta`, `pasta 12 min`, `pasta for 12 min` | A named timer |
| `4x 1h`, `4* 1h`, `1h x4` | Four timers of one hour (up to 20); they count once in your recents |
| `at 18:30`, `at 6pm`, `at noon`, `à 18h` | An alarm at a time of day (tomorrow if already past) |
| `timer 14h30` | Offers both: *alarm at 14:30* first, *14 h 30 timer* second |

**Limits.** A timer lasts between 1 second and 100 hours, `4x` goes up to 20 timers at once (`99x 1h` starts 20 and says so), at most 50 timers run together (`4x 1h` with two places left starts two and says *Started 2 of 4*), a query is read up to 200 characters and a label keeps its first 60. Anything outside these limits, or a query Sands can't read, shows a short message with a link back to this section: nothing is refused silently. `dms ipc call smartTimer add` follows the same 100-hour limit.

The interface is in English. Want Sands to understand another language? [Open an issue](https://github.com/lung595/Sands/issues).

## Settings

| Setting | Description | Default |
| --- | --- | --- |
| Hourglass | Classic or Glass of Time | Classic |
| Sound | One of the two rings that come with Sands, any installed sound theme file, or your own file: see [Sound](#sound) | Hourglass |
| Volume | | 80 % |
| Alarm duration | The sound stops by itself; the pill keeps pulsing | 60 s |
| Notification when done | With *Stop* and *+5 min* | On |
| Gentle alarm | Starts at 30 %, rises to full volume | On |
| Final countdown ticks | A soft tick on each of the last 10 seconds | Off |
| Respect Do Not Disturb | No sound; the pill still pulses | On |
| Automatic detection / Prefix | Answer any duration in the launcher, or only after your prefix | Automatic detection |

DMS's *Reduce motion* is respected: no floating, no spin or flip animation.

### Sound

The list starts with the two rings that come with Sands, then the sounds installed on the machine, then *Custom file…*. *Preview* plays the choice shown, at the volume you set.

- **Hourglass** (default): four soft rising glass notes, one grain after the other. Made for Sands.
- **Silt Chime**: a short, soft bell struck twice.
- **A system sound**: any `.oga`, `.ogg`, `.wav`, `.mp3` or `.flac` of the installed sound themes or of `~/.local/share/sounds`. The former default, *Alarm clock elapsed*, is now one of them.
- **Custom file…**: type a full path, or one starting with `~/`, in *Sound file*.

Both rings start within 150 ms and begin and end on silence, so they work with *Gentle alarm* (which starts at 30 %) and loop without a click. An unset *Sound* plays Hourglass; a sound you chose yourself keeps playing as saved.

### If the alarm makes no sound

When the alarm cannot play its sound, Sands says so instead of staying quiet: **The alarm made no sound** (in the panel if it is open, otherwise as a DMS notification). **Preview** in the settings does the same with **Could not play this sound**. The pill still pulses either way.

- **A file of your own**: check the path in *Sound file* (a full path, or one starting with `~/`) and that the file is an `.oga`, `.ogg`, `.wav`, `.mp3` or `.flac` you can open.
- **A sound theme file**: pick another one in *Sound*. Hourglass and Silt Chime are files of Sands itself, so they need nothing else; the system sounds come from your sound theme packages, such as `sound-theme-freedesktop`.
- **No player**: Sands plays with `pw-play` (PipeWire) and falls back to `paplay`. Run `pw-play /usr/share/sounds/freedesktop/stereo/complete.oga` in a terminal: an error there is the same one Sands met.
- **Nothing is wrong but it is silent**: *Volume* is at 0, the output device is muted, or *Respect Do Not Disturb* is on while Do Not Disturb is active (no message then: that silence is on purpose).

## Privacy

- **No network access, no telemetry.** The guide links in messages open in your browser only when you click them.
- **Short-lived local tools only**: `pw-play` (or `paplay`) to ring, `notify-send` / `gdbus` for the notification, and a one-off `find` over the system sound folders while the settings page is open.
- **Written to disk**, through DMS's plugin state: your running timers (end times and labels) and your recent timers. Nothing else.
- **Settings** are stored by DMS with your other plugin settings.

## Performance

Sands costs nothing while you are not looking at it. In % of one CPU core for the whole shell, 240 Hz display (DMS alone: about 2 %):

| Situation | 1.3.0 |
| --- | --- |
| Timer running, panel closed | Same as DMS alone (2.1 %) |
| Panel open, sand flowing | 6.5 % |
| Panel open, paused (frozen) | 3.9 % |

How this is achieved is in [CONTRIBUTING.md](../CONTRIBUTING.md#performance-rules).
