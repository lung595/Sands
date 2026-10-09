import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "TimeParser.js" as TP
import "Timers.js" as Timers
import "Guide.js" as Guide

// Timer engine, instantiated once. The bar and the launcher
// reach it through PluginService.pluginDaemonInstances["smartTimer"].
//
// A running timer does not store a remaining time but its end time
// (endAt): nothing drifts, and a DMS restart finds it exactly where it
// was. Every change replaces the `timers` array (QML bindings update) and
// is saved in the plugin state.
Item {
    id: root
    // Look of the panel's hourglass: "classic" or "glassOfTime"
    readonly property string hourglassStyle: SettingsData.pluginSettings["smartTimer"]?.hourglassStyle || "classic"

    property string pluginId: "smartTimer"
    property var pluginService: null

    // The rings shipped with the plugin, as a local path ending with "/".
    readonly property string ringDir: decodeURIComponent(Qt.resolvedUrl("sounds/").toString().replace(/^file:\/\//, ""))

    // { id, label, kind: "duration"|"at", total, endAt, remaining,
    //   state: "running"|"paused"|"ringing", finishedAt }
    property var timers: []
    property real now: Date.now()

    // Display order: ringing first, then the soonest to finish, then
    // paused ones. Does not depend on the clock (the order of end times does
    // not change over time): recomputed only when the list changes.
    readonly property var sorted: {
        const rank = t => t.state === "ringing" ? 0 : (t.state === "running" ? 1 : 2);
        const key = t => t.state === "running" ? t.endAt : (t.state === "paused" ? t.remaining : t.finishedAt);
        return timers.slice().sort((a, b) => rank(a) - rank(b) || key(a) - key(b));
    }
    readonly property var primary: sorted.length > 0 ? sorted[0] : null
    readonly property int count: timers.length
    readonly property bool hasTimers: timers.length > 0
    readonly property bool ringing: timers.some(t => t.state === "ringing")
    property bool soundActive: false

    // Durations used before, most frequent and recent first:
    // [{ ms, label, uses, last }]. Feeds a bare "timer" in the launcher.
    property var recents: []

    // Emitted when a timer starts or restarts: the pill then briefly
    // shows its name ("dynamic island" effect).
    signal timerStarted(int id)
    // Opens/closes the panel on the active screen (keyboard shortcut, IPC).
    signal panelRequested(string screenName)

    property int _nextId: 1
    property bool _loaded: false

    function setting(key, fallback) {
        return pluginService ? pluginService.loadPluginData(pluginId, key, fallback) : fallback;
    }

    function use24h() {
        return SettingsData.use24HourClock !== false;
    }

    // ------------------------------------------------------------------
    // Queries
    // ------------------------------------------------------------------

    // The pure logic lives in Timers.js (tested with gjs); these read the
    // daemon's clock for it
    function remainingOf(t, n) {
        return Timers.remainingOf(t, n === undefined ? now : n);
    }

    function progressOf(t) {
        return Timers.progressOf(t, now);
    }

    function find(id) {
        for (let i = 0; i < timers.length; i++) {
            if (timers[i].id === id)
                return timers[i];
        }
        return null;
    }

    function displayLabel(t) {
        return Timers.displayLabel(t);
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------

    function _update(id, fn) {
        let changed = false;
        const list = timers.map(t => {
            if (t.id !== id)
                return t;
            const copy = Object.assign({}, t);
            fn(copy);
            changed = true;
            return copy;
        });
        if (changed)
            _commit(list);
        return changed;
    }

    function _commit(list) {
        timers = list;
        now = Date.now();
        if (pluginService && _loaded) {
            pluginService.savePluginState(pluginId, "timers", list);
            pluginService.savePluginState(pluginId, "nextId", _nextId);
        }
        if (!list.some(t => t.state === "ringing"))
            silence();
        _syncNotifications(list);
        _schedule();
    }

    function _remember(ms, label) {
        const list = Timers.remember(recents, ms, label, Date.now());
        recents = list;
        if (pluginService)
            pluginService.savePluginState(pluginId, "recents", list);
    }

    // Hard limits: a script or a typo can't fill the disk or the bar.
    readonly property int maxTimers: 50
    readonly property string guideUrl: "https://github.com/lung595/Sands/blob/main/docs/GUIDE.md"

    // The note the open panel shows ({ title, hint, anchor }, see Guide.js),
    // null when there is none
    property var note: null
    // Panels currently on screen; a note needs one, otherwise it is a toast
    property var _panels: []
    readonly property bool panelOpen: _panels.length > 0

    // Called by each panel when it shows or hides
    function panelShown(panel, on) {
        const rest = _panels.filter(p => p !== panel);
        _panels = on ? rest.concat([panel]) : rest;
        // A closed panel forgets its note: it would be stale when reopened
        if (!panelOpen)
            note = null;
    }

    // Says why something did not happen and what to do, with a link to the
    // guide section (value 10: never refuse silently). In the panel when it
    // is open, otherwise as a DMS toast. The link opens only on click.
    function explain(n) {
        if (panelOpen)
            note = n;
        else if (typeof ToastService !== "undefined")
            ToastService.showError(Guide.toastText(n), guideUrl + "#" + n.anchor);
    }

    function _make(ms, label, kind, at, t0) {
        const endAt = kind === "at" && at ? at : t0 + ms;
        return {
            id: _nextId++,
            label: String(label || "").substring(0, TP.MAX_LABEL).trim(),
            kind: kind === "at" ? "at" : "duration",
            total: endAt - t0,
            endAt: endAt,
            remaining: endAt - t0,
            state: "running",
            finishedAt: 0,
            hue: 0
        };
    }

    function start(ms, label, kind, at, remember) {
        return startMany(ms, label, kind, at, 1, remember);
    }

    // « 4x 1h »: `count` timers of the same duration, saved in a single
    // write and remembered once in the recents, not four times.
    // Returns the first id, or -1 when nothing was started; how many
    // actually started, and why not, are kept for the IPC answer.
    property int lastStarted: 0
    property var lastRefusal: null
    function startMany(ms, label, kind, at, count, remember) {
        ms = Math.round(ms);
        lastStarted = 0;
        if (!(ms >= 1000) || ms > TP.MAX_MS) {
            lastRefusal = Guide.rangeNote();
            explain(lastRefusal);
            return -1;
        }
        const wanted = kind === "at" ? 1 : Math.max(1, Math.min(TP.MAX_COUNT, Math.round(count || 1)));
        const n = Math.min(wanted, maxTimers - timers.length);
        lastStarted = Math.max(0, n);
        if (n <= 0) {
            lastRefusal = Guide.fullNote(maxTimers);
            explain(lastRefusal);
            return -1;
        }
        if (n < wanted)
            explain(Guide.partialNote(n, wanted, maxTimers));
        const t0 = Date.now();
        let list = timers;
        const ids = [];
        for (let i = 0; i < n; i++) {
            const t = _make(ms, label, kind, at, t0);
            t.hue = Timers.freeHue(list, hueCount);
            list = list.concat([t]);
            ids.push(t.id);
        }
        _commit(list);
        if (kind !== "at" && remember !== false)
            _remember(ms, (label || "").trim());
        ids.forEach(id => timerStarted(id));
        return ids[0];
    }

    // Each timer has its own color (sand, ring, list): the first
    // takes the accent color, the next ones neighboring hues. The first
    // free hue is reused, so colors stay stable.
    readonly property int hueCount: 6
    function _freeHue() {
        return Timers.freeHue(timers, hueCount);
    }

    function colorFor(t) {
        const base = Theme.primary;
        const idx = t && t.hue !== undefined ? t.hue : 0;
        if (idx === 0)
            return base;
        const shifts = [0, 0.5, 0.17, 0.66, 0.33, 0.83];
        const h = (Math.max(0, base.hslHue) + shifts[idx % shifts.length]) % 1;
        return Qt.hsla(h, Math.max(0.45, base.hslSaturation), Math.min(0.78, Math.max(0.55, base.hslLightness)), 1);
    }

    // Same syntax as the launcher: startText("12 min pâtes").
    function startText(text) {
        const res = TP.parse(text, Date.now(), { keyword: true });
        if (res.length === 0)
            return null;
        // Understood but refused (out of range, no room left): r.started is 0
        const r = res[0];
        startMany(r.ms, r.label, r.kind, r.at, r.count);
        r.started = lastStarted;
        return r;
    }

    function pause(id) {
        const t0 = Date.now();
        return _update(id, t => {
            if (t.state !== "running")
                return;
            t.remaining = Math.max(0, t.endAt - t0);
            t.state = "paused";
        });
    }

    function resume(id) {
        const t0 = Date.now();
        return _update(id, t => {
            if (t.state !== "paused")
                return;
            t.endAt = t0 + t.remaining;
            t.state = "running";
        });
    }

    function toggle(id) {
        const t = find(id);
        if (!t)
            return false;
        if (t.state === "running")
            return pause(id);
        if (t.state === "paused")
            return resume(id);
        return dismiss(id);
    }

    // Adds (or removes) time. On a ringing timer: restarts it for
    // that duration ("+1 min" = repeat).
    // Returns false when nothing changed (unknown id, out of range).
    function adjust(id, deltaMs) {
        const t0 = Date.now();
        let ok = false;
        return _update(id, t => {
            if (t.state === "ringing") {
                if (deltaMs <= 0 || deltaMs > TP.MAX_MS)
                    return;
                ok = true;
                t.state = "running";
                t.endAt = t0 + deltaMs;
                t.total = deltaMs;
                t.finishedAt = 0;
                t.kind = "duration";
                return;
            }
            const rem = t.state === "running" ? t.endAt - t0 : t.remaining;
            const next = rem + deltaMs;
            if (next < 1000 || next > TP.MAX_MS)
                return;
            ok = true;
            if (t.state === "running")
                t.endAt += deltaMs;
            else
                t.remaining = next;
            t.total = Math.max(t.total + Math.max(0, deltaMs), next);
        }) && ok;
    }

    function restart(id) {
        const t0 = Date.now();
        Qt.callLater(() => root.timerStarted(id));
        return _update(id, t => {
            const dur = t.kind === "at" ? Math.max(t.total, 1000) : t.total;
            t.kind = "duration";
            t.total = dur;
            t.endAt = t0 + dur;
            t.remaining = dur;
            t.state = "running";
            t.finishedAt = 0;
        });
    }

    function remove(id) {
        const list = timers.filter(t => t.id !== id);
        if (list.length === timers.length)
            return false;
        _commit(list);
        return true;
    }

    function dismiss(id) {
        return remove(id);
    }

    function dismissRinging() {
        const list = timers.filter(t => t.state !== "ringing");
        if (list.length !== timers.length)
            _commit(list);
        silence();
    }

    function clear() {
        _commit([]);
    }

    // ------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------

    function _tick() {
        const t0 = Date.now();
        now = t0;
        let fired = false;
        const list = timers.map(t => {
            if (t.state !== "running" || t.endAt > t0)
                return t;
            fired = true;
            return Object.assign({}, t, {
                state: "ringing",
                finishedAt: t.endAt,
                remaining: 0
            });
        });
        // Subtle ticking during the last 10 seconds (optional).
        if (!fired && setting("tick", false) && !_muted() && list.some(t => t.state === "running" && t.endAt - t0 > 0 && t.endAt - t0 <= 10050))
            _playTick();
        if (fired) {
            const newly = list.filter(t => t.state === "ringing" && !_notifiers[t.id]);
            _commit(list);
            startRinging();
            newly.forEach(t => _notify(t));
        }
    }

    // ------------------------------------------------------------------
    // End notification with actions (useful in fullscreen, bar hidden)
    // ------------------------------------------------------------------

    // timer id → { proc, notifId }
    property var _notifiers: ({})

    function _notify(t) {
        if (!setting("notify", true) || _notifiers[t.id])
            return;
        const body = t.kind === "at" ? "It's " + TP.formatTimeOfDay(t.endAt, use24h()) : TP.formatHuman(t.total) + " elapsed";
        const proc = notifierComp.createObject(root, {
            timerId: t.id,
            command: ["notify-send", "-a", "Sands", "-i", "alarm-symbolic", "-u", "critical", "-p", "-A", "stop=" + "Stop", "-A", "snooze=+5 min", displayLabel(t) + " — done", body]
        });
        const map = Object.assign({}, _notifiers);
        map[t.id] = {
            proc: proc,
            notifId: 0
        };
        _notifiers = map;
        proc.running = true;
    }

    // Closes the notifications of timers that are no longer ringing.
    function _syncNotifications(list) {
        for (const key in _notifiers) {
            const id = parseInt(key);
            const t = list.find(x => x.id === id);
            if (t && t.state === "ringing")
                continue;
            const n = _notifiers[key];
            if (n.notifId > 0)
                Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.CloseNotification", String(n.notifId)]);
            const map = Object.assign({}, _notifiers);
            delete map[key];
            _notifiers = map;
        }
    }

    Component {
        id: notifierComp

        Process {
            id: proc
            property int timerId: 0

            stdout: SplitParser {
                onRead: line => {
                    const v = line.trim();
                    const n = root._notifiers[proc.timerId];
                    if (/^\d+$/.test(v)) {
                        if (n)
                            n.notifId = parseInt(v);
                        return;
                    }
                    if (v === "stop")
                        root.dismiss(proc.timerId);
                    else if (v === "snooze")
                        root.adjust(proc.timerId, 300000);
                }
            }

            onExited: {
                const map = Object.assign({}, root._notifiers);
                if (map[proc.timerId] && map[proc.timerId].proc === proc) {
                    delete map[proc.timerId];
                    root._notifiers = map;
                }
                proc.destroy();
            }
        }
    }

    // Wake-up aligned on the next change of the displayed second (≈ once
    // per second), and no wake-up at all when everything is paused.
    function _schedule() {
        const t0 = Date.now();
        let next = -1;
        for (let i = 0; i < timers.length; i++) {
            const t = timers[i];
            let d = -1;
            if (t.state === "running") {
                const r = t.endAt - t0;
                d = r <= 0 ? 0 : (r % 1000 || 1000);
            } else if (t.state === "ringing") {
                d = 1000 - ((t0 - t.finishedAt) % 1000);
            }
            if (d >= 0 && (next < 0 || d < next))
                next = d;
        }
        if (next < 0) {
            ticker.stop();
            return;
        }
        ticker.interval = Math.max(8, next + 4);
        ticker.restart();
    }

    Timer {
        id: ticker
        repeat: false
        onTriggered: {
            root._tick();
            root._schedule();
        }
    }

    // ------------------------------------------------------------------
    // Sound
    // ------------------------------------------------------------------

    property real _ringStartedAt: 0
    property bool _useFallbackPlayer: false

    // The file the alarm plays; `choice` and `custom` default to the saved
    // settings, Preview passes what is shown in the settings page.
    function soundPath(choice, custom) {
        return Timers.soundFile(choice === undefined ? setting("sound", "") : choice, custom === undefined ? setting("customSound", "") : custom, Quickshell.env("HOME"), ringDir);
    }

    function _volume() {
        const v = parseInt(setting("volume", 80));
        return Math.max(0, Math.min(100, isNaN(v) ? 80 : v)) / 100;
    }

    function _command(path, volume) {
        if (_useFallbackPlayer)
            return ["paplay", "--volume=" + Math.round(volume * 65536), path];
        return ["pw-play", "--volume=" + volume.toFixed(2), "--", path];
    }

    // "Do not disturb": the pill pulses, but no sound.
    function _muted() {
        return setting("respectDnd", true) && SessionData.doNotDisturb;
    }

    property int _ringCount: 0

    // How long an alarm makes noise and moves (the same setting for both).
    function ringLimitMs() {
        return Math.max(5, parseInt(setting("ringDuration", 60)) || 60) * 1000;
    }

    function startRinging() {
        if (_muted())
            return;
        _ringStartedAt = Date.now();
        _ringCount = 0;
        soundActive = true;
        _playOnce();
    }

    function _playOnce() {
        if (!soundActive)
            return;
        // Rising alarm: 30%, 65%, then full volume.
        const ramp = setting("rampUp", true) ? Math.min(1, 0.3 + 0.35 * _ringCount) : 1;
        _ringCount++;
        ringPlayer.command = _command(soundPath(), _volume() * ramp);
        ringPlayer.startedAt = Date.now();
        ringPlayer.running = true;
    }

    // Silences the sound; the timer stays "finished" (the pill pulses) until
    // it is stopped or restarted.
    function silence() {
        soundActive = false;
        ringGap.stop();
        if (ringPlayer.running)
            ringPlayer.running = false;
    }

    // A new preview waits for the previous one to stop, so a player we
    // stopped ourselves is never mistaken for a file that cannot be played.
    function previewSound(path) {
        previewPlayer.path = path || soundPath();
        if (previewPlayer.running) {
            previewPlayer.next = true;
            previewPlayer.running = false;
        } else {
            _playPreview();
        }
    }

    function _playPreview() {
        previewPlayer.command = _command(previewPlayer.path, _volume());
        previewPlayer.startedAt = Date.now();
        previewPlayer.running = true;
    }

    Process {
        id: ringPlayer
        property real startedAt: 0
        onExited: (exitCode, exitStatus) => {
            if (!root.soundActive)
                return;
            // pw-play missing or failing right away: fall back to paplay.
            if (exitCode !== 0 && !root._useFallbackPlayer && Date.now() - startedAt < 1500) {
                root._useFallbackPlayer = true;
                root._playOnce();
                return;
            }
            if (exitCode !== 0) {
                root.soundActive = false;
                // Both players failed: the file is the problem, so keep
                // pw-play as the first choice next time
                root._useFallbackPlayer = false;
                root.explain(Guide.silentNote());
                return;
            }
            if (Date.now() - root._ringStartedAt >= root.ringLimitMs()) {
                root.soundActive = false;
                return;
            }
            ringGap.restart();
        }
    }

    Timer {
        id: ringGap
        interval: 450
        onTriggered: root._playOnce()
    }

    Process {
        id: previewPlayer
        property string path: ""
        property bool next: false
        property bool closing: false
        property real startedAt: 0
        onExited: (exitCode, exitStatus) => {
            if (next) {
                next = false;
                root._playPreview();
                return;
            }
            if (exitCode === 0 || closing)
                return;
            // Same fallback as the alarm: pw-play missing or failing at once
            if (!root._useFallbackPlayer && Date.now() - startedAt < 1500) {
                root._useFallbackPlayer = true;
                root._playPreview();
                return;
            }
            root._useFallbackPlayer = false;
            root.explain(Guide.previewNote());
        }
    }

    readonly property string tickSound: "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
    function _playTick() {
        tickPlayer.running = false;
        tickPlayer.command = _command(tickSound, _volume() * 0.35);
        tickPlayer.running = true;
    }

    Process {
        id: tickPlayer
    }

    // ------------------------------------------------------------------
    // Persistence and startup
    // ------------------------------------------------------------------

    Component.onCompleted: {
        if (!pluginService)
            return;

        // The launcher works without a prefix by default (« 20 min » is enough).
        // Without this explicit setting, DMS would fall back to the "!" trigger.
        if (pluginService.loadPluginData(pluginId, "noTrigger", null) === null)
            pluginService.savePluginData(pluginId, "noTrigger", true);

        const saved = pluginService.loadPluginState(pluginId, "timers", []);
        _nextId = pluginService.loadPluginState(pluginId, "nextId", 1);
        const t0 = Date.now();
        let ringNow = false;
        const list = (Array.isArray(saved) ? saved : []).filter(t => t && t.id !== undefined).map(t => {
            const copy = Object.assign({}, t);
            if (copy.state === "running" && copy.endAt <= t0) {
                copy.state = "ringing";
                copy.finishedAt = copy.endAt;
                copy.remaining = 0;
                // Finished while the shell was off: ring only if it just happened.
                if (t0 - copy.endAt < 60000)
                    ringNow = true;
            }
            _nextId = Math.max(_nextId, copy.id + 1);
            return copy;
        });
        recents = Timers.rankRecents(pluginService.loadPluginState(pluginId, "recents", []) || [], Date.now());
        _loaded = true;
        timers = list;
        now = t0;
        _schedule();
        if (ringNow)
            startRinging();
        list.filter(t => t.state === "ringing" && t0 - t.finishedAt < 60000).forEach(t => _notify(t));
    }

    Component.onDestruction: {
        ticker.stop();
        ringGap.stop();
        ringPlayer.running = false;
        previewPlayer.closing = true;
        previewPlayer.running = false;
    }

    // ------------------------------------------------------------------
    // IPC: dms ipc call smartTimer <function> [arguments]
    // ------------------------------------------------------------------

    IpcHandler {
        target: "smartTimer"

        // dms ipc call smartTimer start "12 min pâtes"
        function start(text: string): string {
            if (TP.tooLong(text))
                return "Not started: keep it under " + TP.MAX_INPUT + " characters, like \"12 min pasta\": " + root.guideUrl + "#syntax";
            const r = root.startText(text);
            if (!r)
                return "Not started. Try \"12 min pasta\": " + root.guideUrl + "#syntax";
            if (r.started === 0)
                return "Not started: " + root.lastRefusal.hint + ". " + root.guideUrl + "#" + root.lastRefusal.anchor;
            const partial = r.started < (r.count || 1);
            const times = partial ? r.started + " of " + r.count + " × " : (r.kind === "duration" && r.count > 1 ? r.count + " × " : "");
            const limit = partial ? " (at most " + root.maxTimers + " at once: " + root.guideUrl + "#syntax)" : "";
            return "Started: " + times + (r.label || (r.kind === "at" ? "Alarm" : "Timer")) + " — " + (r.kind === "at" ? "at " + TP.formatTimeOfDay(r.at, root.use24h()) : TP.formatHuman(r.ms)) + limit;
        }

        // Pauses / resumes the nearest timer; stops the alarm.
        function toggle(): string {
            if (root.ringing) {
                root.dismissRinging();
                return "Alarm stopped";
            }
            if (!root.primary)
                return "No timer";
            root.toggle(root.primary.id);
            return "OK";
        }

        function pause(): string {
            root.timers.filter(t => t.state === "running").forEach(t => root.pause(t.id));
            return "OK";
        }

        function resume(): string {
            root.timers.filter(t => t.state === "paused").forEach(t => root.resume(t.id));
            return "OK";
        }

        // Stops whatever is ringing, otherwise cancels the nearest timer.
        function stop(): string {
            if (root.ringing) {
                root.dismissRinging();
                return "Alarm stopped";
            }
            if (!root.primary)
                return "No timer";
            root.remove(root.primary.id);
            return "Timer cancelled";
        }

        // dms ipc call smartTimer add 5  → +5 min on the nearest timer
        function add(minutes: int): string {
            if (!root.primary)
                return "No timer";
            if (!root.adjust(root.primary.id, minutes * 60000))
                return "Not changed: a timer lasts between 1 second and 100 hours. " + root.guideUrl + "#syntax";
            return "OK";
        }

        // Bind to a shortcut: opens / closes the panel on the active screen.
        function panel(): string {
            const scr = CompositorService.getFocusedScreen();
            root.panelRequested(scr ? scr.name : "");
            return "OK";
        }

        function clear(): string {
            root.clear();
            return "All timers cleared";
        }

        function list(): string {
            if (root.timers.length === 0)
                return "No timer";
            return root.sorted.map(t => {
                const state = t.state === "paused" ? " (paused)" : (t.state === "ringing" ? " (done)" : "");
                return root.displayLabel(t) + "\t" + TP.formatClock(root.remainingOf(t)) + state;
            }).join("\n");
        }
    }
}
