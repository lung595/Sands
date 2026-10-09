import QtQuick
import "../../../Timers.js" as Timers

// Stand-in for TimerDaemon in the preview scenes: the same read API, made-up
// timers, actions that do nothing. The clock is frozen at `base` so a
// picture is the same on every run; `live` lets it follow the real time (for
// the bench scenes, which must keep moving).
QtObject {
    id: fake

    // Fixed instant of the pictures (any value works, only the offsets matter)
    readonly property real base: 1800000000000
    property bool live: false
    property real now: base
    property var timers: []
    property var note: null
    property bool soundActive: false
    property string hourglassStyle: "classic"
    readonly property string guideUrl: "file:///dev/null"

    readonly property var sorted: {
        const rank = t => t.state === "ringing" ? 0 : (t.state === "running" ? 1 : 2);
        const key = t => t.state === "running" ? t.endAt : (t.state === "paused" ? t.remaining : t.finishedAt);
        return timers.slice().sort((a, b) => rank(a) - rank(b) || key(a) - key(b));
    }
    readonly property var primary: sorted.length > 0 ? sorted[0] : null
    readonly property int count: timers.length
    readonly property bool hasTimers: timers.length > 0
    readonly property bool ringing: timers.some(t => t.state === "ringing")

    signal timerStarted(int id)
    signal panelRequested(string screenName)

    property Timer clock: Timer {
        interval: 1000
        repeat: true
        running: fake.live
        onTriggered: fake.now = Date.now()
    }

    // Timers as the scenes name them: [state, label, total ms, ms left, hue]
    function load(specs) {
        const origin = live ? Date.now() : base;
        now = origin;
        timers = specs.map((s, i) => ({
                    id: i + 1,
                    state: s[0],
                    label: s[1],
                    kind: "timer",
                    total: s[2],
                    endAt: origin + s[3],
                    remaining: s[3],
                    finishedAt: origin,
                    hue: s[4]
                }));
    }

    function remainingOf(t, n) {
        return Timers.remainingOf(t, n === undefined ? now : n);
    }
    function progressOf(t) {
        return Timers.progressOf(t, now);
    }
    function find(id) {
        return timers.find(t => t.id === id) ?? null;
    }
    function displayLabel(t) {
        return Timers.displayLabel(t);
    }
    function colorFor(t) {
        // Same hue slots as the daemon, from the default purple
        const base = Qt.color("#D0BCFF");
        const idx = t && t.hue !== undefined ? t.hue : 0;
        if (idx === 0)
            return base;
        const shifts = [0, 0.5, 0.17, 0.66, 0.33, 0.83];
        const h = (Math.max(0, base.hslHue) + shifts[idx % shifts.length]) % 1;
        return Qt.hsla(h, Math.max(0.45, base.hslSaturation), Math.min(0.78, Math.max(0.55, base.hslLightness)), 1);
    }
    function ringLimitMs() {
        return 60000;
    }

    // Actions: a picture never clicks
    function panelShown(panel, shown) {
    }
    function adjust(id, ms) {
    }
    function remove(id) {
    }
    function toggle(id) {
    }
    function restart(id) {
    }
    function dismiss(id) {
    }
    function dismissRinging() {
    }
}
