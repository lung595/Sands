import QtQuick
import qs.Common
import qs.Services
import "TimeParser.js" as TP
import "Timers.js" as Timers
import "Guide.js" as Guide
import "components/daemon"
import "components/daemon/Lifecycle.js" as Lifecycle
import "components/daemon/Notifications.js" as Notifications

// Timer engine, instantiated once. The bar and the launcher
// reach it through PluginService.pluginDaemonInstances["smartTimer"].
//
// A running timer does not store a remaining time but its end time
// (endAt): nothing drifts, and a DMS restart finds it exactly where it
// was. Every change replaces the `timers` array (QML bindings update) and
// is saved in the plugin state.
//
// This file owns the timer list, its actions and the clock. The rest has one
// file each in components/daemon/: TimerStore (persistence), AlarmSound
// (every sound), TimerNotifier (end notification), TimerIpc (the `dms ipc`
// commands), and the pure rules in the .js files next to them.
Item {
    id: root
    // Look of the panel's hourglass: "classic" or "glassOfTime"
    readonly property string hourglassStyle: SettingsData.pluginSettings["smartTimer"]?.hourglassStyle || "classic"

    property string pluginId: "smartTimer"
    property var pluginService: null

    // { id, label, kind: "duration"|"at", total, endAt, remaining,
    //   state: "running"|"paused"|"ringing", finishedAt }
    property var timers: []
    property real now: Date.now()

    // Display order, see Lifecycle.sortTimers. Does not depend on the clock
    // (the order of end times does not change over time): recomputed only
    // when the list changes.
    readonly property var sorted: Lifecycle.sortTimers(timers)
    readonly property var primary: sorted.length > 0 ? sorted[0] : null
    readonly property int count: timers.length
    readonly property bool hasTimers: timers.length > 0
    readonly property bool ringing: timers.some(t => t.state === "ringing")
    // The pill shakes its bell only while a sound really plays, not for a muted ring
    readonly property bool soundActive: alarm.active

    // Durations used before, most frequent and recent first:
    // [{ ms, label, uses, last }]. Feeds a bare "timer" in the launcher.
    property var recents: []

    // Emitted when a timer starts or restarts: the pill then briefly
    // shows its name ("dynamic island" effect).
    signal timerStarted(int id)
    // Opens/closes the panel on the active screen (keyboard shortcut, IPC).
    signal panelRequested(string screenName)

    property int _nextId: 1

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
    // Sound (see AlarmSound.qml)
    // ------------------------------------------------------------------

    function soundPath(choice, custom) {
        return alarm.soundPath(choice, custom);
    }

    function previewSound(path) {
        alarm.preview(path);
    }

    function ringLimitMs() {
        return alarm.ringLimitMs();
    }

    function silence() {
        alarm.silence();
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
        store.saveTimers(list, _nextId);
        if (!list.some(t => t.state === "ringing"))
            silence();
        notifier.sync(list);
        _schedule();
    }

    function _remember(ms, label) {
        const list = Timers.remember(recents, ms, label, Date.now());
        recents = list;
        store.saveRecents(list);
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
            const t = Lifecycle.make(_nextId++, ms, label, kind, at, t0, TP.MAX_LABEL);
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
        const res = TP.parse(text, Date.now(), {
            keyword: true
        });
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
        return _update(id, t => Lifecycle.pause(t, t0));
    }

    function resume(id) {
        const t0 = Date.now();
        return _update(id, t => Lifecycle.resume(t, t0));
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
            ok = Lifecycle.adjust(t, t0, deltaMs, TP.MAX_MS);
        }) && ok;
    }

    function restart(id) {
        const t0 = Date.now();
        Qt.callLater(() => root.timerStarted(id));
        return _update(id, t => Lifecycle.restart(t, t0));
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
        const r = Lifecycle.expire(timers, t0);
        // Subtle ticking during the last 10 seconds (optional).
        if (!r.fired && setting("tick", false) && !alarm.muted() && Lifecycle.inFinalSeconds(r.list, t0))
            alarm.playTick();
        if (r.fired) {
            const newly = r.list.filter(t => t.state === "ringing" && !notifier.has(t.id));
            _commit(r.list);
            alarm.startRinging();
            newly.forEach(t => _notify(t));
        }
    }

    function _notify(t) {
        if (setting("notify", true))
            notifier.show(t, displayLabel(t), Notifications.body(t, use24h()));
    }

    // Wake-up aligned on the next change of the displayed second (≈ once
    // per second), and no wake-up at all when everything is paused.
    function _schedule() {
        const next = Lifecycle.nextDelay(timers, Date.now());
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

    TimerStore {
        id: store
        pluginService: root.pluginService
        pluginId: root.pluginId
    }

    AlarmSound {
        id: alarm
        engine: root
    }

    TimerNotifier {
        id: notifier
        onStopRequested: id => root.dismiss(id)
        onSnoozeRequested: id => root.adjust(id, 300000)
    }

    TimerIpc {
        engine: root
    }

    // ------------------------------------------------------------------
    // Startup
    // ------------------------------------------------------------------

    Component.onCompleted: {
        if (!pluginService)
            return;
        store.ensureLauncherDefault();

        const saved = store.read();
        const t0 = Date.now();
        const state = Lifecycle.restore(saved.timers, saved.nextId, t0);
        _nextId = state.nextId;
        recents = Timers.rankRecents(saved.recents, t0);
        store.loaded = true;
        timers = state.list;
        now = t0;
        _schedule();
        if (state.ringNow)
            alarm.startRinging();
        state.recent.forEach(t => _notify(t));
    }

    Component.onDestruction: {
        ticker.stop();
        alarm.shutdown();
    }
}
