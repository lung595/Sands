import QtQuick

// The hourglass clocks, all driven by one plain Timer.
//
// A FrameAnimation (or any looping QML animation) would make every DMS window
// redraw at the display rate: measured, the open panel cost 87 % of a core,
// 106 % when paused. A Timer only redraws the panel: 60 Hz while grains fall,
// 30 Hz for the slow float, mist and pulses. With Reduce motion nothing
// floats, so it only runs while grains fall or the alarm pulses.
//
// It is a child of the hourglass, so `visible` is the hourglass's: nothing
// ticks while the panel is hidden.
Item {
    id: root

    required property bool running
    required property bool paused
    required property bool ringing
    // false when the panel is closed: no frame is computed anymore.
    required property bool animate
    required property bool reducedMotion

    // Grain clock: slows down to a stop when freezing.
    property real speed: (paused || !running) ? 0 : 1
    Behavior on speed {
        NumberAnimation {
            duration: 900
            easing.type: Easing.OutCubic
        }
    }
    property real clock: 0

    // Floating: never stops. Frozen, it slows down and tightens,
    // as at absolute zero: almost still, but not quite.
    property real floatClock: 0
    property real floatSpeed: paused ? 0.3 : 1
    property real floatAmp: reducedMotion ? 0 : (paused ? 1.6 : 5)
    Behavior on floatSpeed {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on floatAmp {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.InOutCubic
        }
    }

    // Effects clock (s): drives the pulses here and the frost mist and
    // crystals of the panel (Motion.js).
    property real fxTime: 0

    readonly property bool motionNeeded: !reducedMotion || speed > 0.001 || ringing
    Timer {
        id: motion
        interval: root.speed > 0.001 ? 16 : 33
        repeat: true
        running: root.visible && root.animate && root.motionNeeded
        property real last: 0
        onRunningChanged: last = 0
        onTriggered: {
            const now = Date.now();
            // Real elapsed time, capped so a late tick does not jump.
            const dt = last > 0 ? Math.min(0.1, (now - last) / 1000) : interval / 1000;
            last = now;
            root.fxTime += dt;
            root.floatClock += dt * root.floatSpeed;
            if (root.speed > 0.001)
                root.clock += dt * root.speed;
        }
    }
}
