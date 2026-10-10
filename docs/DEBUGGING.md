# Debugging Sands

For someone who has a problem and wants to tell the maintainer about it without giving anything personal away.

## Contents

- [What the report holds](#what-the-report-holds)
- [Reading the journal yourself](#reading-the-journal-yourself)
- [The event codes](#the-event-codes)
- [Cases](#cases)

## What the report holds

An anonymous text you read before you paste it into a GitHub issue. Sands never sends it anywhere: it stays on your machine until you decide to share it.

- **In it:** the time (UTC), the versions of Sands, DMS, Quickshell, Qt and niri, the distribution, which surfaces are active, the settings that choose a behaviour, a few counts (timers, helper programs running), the shell's CPU over one second, the last events Sands recorded and the lines Sands left in the DMS journal.
- **Never in it:** a timer label, a launcher query, a sound file path, a path under your home folder, a host name, your login, an address, a token or any text you typed. Events are built from a fixed list of codes and words; whatever else reaches them is replaced by `?`, and every line is cleaned a second time before it is kept.
- **Not kept:** the events live in memory, at most 200, and vanish with the shell (a restart, a crash, a log out). Nothing is written to disk and nothing runs while nobody asks for a report.

The CPU figure is the **whole shell** (DMS and every plugin together) over one second, measured only when you ask for the report. The shell is one process, so Sands's own share cannot be told apart from it.

The module is in `diagnostics/`; the ways to ask for a report (settings button, `dms ipc call`, script) are not wired yet.

## Reading the journal yourself

Errors and warnings are written to the DMS journal with the tag `[sands]`:

```sh
journalctl --user -u dms -n 300 --no-pager | grep '\[sands\]'
```

Read the lines before you paste them: the shell's own messages can name folders under your home folder.

## The event codes

A code is `SND-` followed by a level letter (`E` error, `W` warning, `I` info, `D` debug) and a number. Errors and warnings reach the journal; info and debug stay in memory. A code's number never changes meaning once released.

| Code | Level | Meaning | Fields |
|---|---|---|---|
| `SND-E001` | error | A timer action (start, pause, resume, stop, add, clear, snooze, dismiss) failed | `action`, `reason` |
| `SND-E002` | error | The saved timers could not be read | `reason` |
| `SND-E003` | error | A helper program (`pw-play`, `paplay`, `notify-send`, `gdbus`, `wl-copy`, `dms`) stopped unexpectedly | `tool`, `code` (its exit status) |
| `SND-E004` | error | The ring sound could not be played | `reason` |
| `SND-W010` | warning | A helper program is missing | `tool` |
| `SND-W011` | warning | A timer text was not understood | `reason` |
| `SND-I020` | info | A surface (widget, daemon, launcher, settings, panel) was loaded | `surface` |
| `SND-I021` | info | A surface was unloaded | `surface` |
| `SND-I030` | info | A diagnostic report was requested | `via` |
| `SND-D040` | debug | A timer changed state (running, paused, ringing, idle) | `state`, `count` |

The words a field may hold are listed in `diagnostics/Codes.js`; a test fails when a code is missing from this table.

## Cases

### The timer does not ring

Look for `SND-E004` (the sound could not be played) and `SND-W010` with `tool=pw_play` (PipeWire's player is missing). Check the `sound` and `volume` lines under Settings in the report.

### The widget or the launcher word does nothing

`SND-W011` says a text was not understood; `SND-I020`/`SND-I021` show which surfaces were loaded and unloaded.

### The shell restarts or the bar freezes

The memory buffer is lost with the shell, so the report right after a restart is empty. Quickshell keeps its own crash folder under `~/.cache/quickshell/crashes/`; it contains paths with your login, so read it before sharing any of it. Sands does not keep a trace on disk.
