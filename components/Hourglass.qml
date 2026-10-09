pragma ComponentBehavior: Bound
import QtQuick
import "hourglass"
import "hourglass/Geometry.js" as Geometry

// Floating hourglass.
//
// Light by design: the glass and the sand are drawn in a Canvas
// that only repaints when the level changes (≈ once per second); everything
// that moves (float, tilt, flip, grains) is a plain item transform, done by
// the GPU, with no repaint. Motion is driven by a plain Timer, not by a QML
// animation: see hourglass/MotionClock.qml.
//
// This file only wires the pieces of hourglass/ together; each of them has a
// single role (clocks, gestures, sand levels, one canvas per layer).
//
// - progress : remaining fraction at the top (1 = full, 0 = empty)
// - frost    : 0 → 1, freeze (driven by the panel, which freezes the whole screen)
// - flip()   : the hourglass turns over (when restarting)
// - wild()   : a happy spin and hop, for fun (a click); changes nothing else
// - style    : "classic", or "glassOfTime" (a nod to the Hourglass of Steven
//              Universe: glass in a cyan sphere, a gold ring around the waist).
//              Only the frame changes; sand, freeze and flip behave the same.
Item {
    id: root

    property real progress: 1
    property bool running: true
    property bool paused: false
    property bool ringing: false
    property real frost: 0
    // false when the panel is closed: no frame is computed anymore.
    property bool animate: true
    // DMS "reduce motion" setting: no floating and no flipping.
    property bool reducedMotion: false

    property color sandColor: "#e0b050"
    property color glassColor: "white"
    property color capColor: "#2a2a2a"
    property color frostColor: Qt.rgba(0.8, 0.9, 1, 1)
    property color shadowColor: "black"
    property string style: "classic"
    readonly property bool gotStyle: style === "glassOfTime"

    // Effects clock (s): the panel's frost mist and crystals follow it.
    readonly property alias fxTime: clocks.fxTime

    function flip() {
        turn.flip();
    }

    function wild() {
        turn.wild();
    }

    implicitWidth: 220
    implicitHeight: 250

    // Geometry (px), shared by the drawing and the grains; the volume table
    // is recomputed only when the size or the style changes.
    readonly property var dim: Geometry.dimensions(width, height, gotStyle)
    readonly property var vol: Geometry.volumes(dim)
    // Freeze in 24 steps: while setting (0.9 s) and melting (0.7 s), the
    // glass is repainted at most 24 times, not every frame.
    readonly property int frostStep: Math.round(frost * 24)
    readonly property bool flowing: sandLevel.shownProgress > 0.0005 && sandLevel.shownProgress < 0.999 && !ringing && turn.flipAngle === 0
    readonly property real floatY: Math.sin(clocks.floatClock * 1.35) * clocks.floatAmp

    MotionClock {
        id: clocks
        running: root.running
        paused: root.paused
        ringing: root.ringing
        animate: root.animate
        reducedMotion: root.reducedMotion
    }

    Turn {
        id: turn
        animate: root.animate
        reducedMotion: root.reducedMotion
    }

    SandLevel {
        id: sandLevel
        progress: root.progress
        dim: root.dim
        vol: root.vol
    }

    GotPalette {
        id: gotPalette
    }

    Halos {
        // Glass of Time: sized on its sphere, within the panel's width
        size: root.gotStyle ? Math.min(root.dim.sphereR * 3.6, root.width * 1.5) : root.dim.hgH * 1.3
        gotStyle: root.gotStyle
        ringing: root.ringing
        reducedMotion: root.reducedMotion
        frost: root.frost
        fxTime: clocks.fxTime
        sandColor: root.sandColor
        frostColor: root.frostColor
    }

    Shadow {
        hgW: root.dim.hgW
        hgH: root.dim.hgH
        floatY: root.floatY
        shadowColor: root.shadowColor
    }

    // The hourglass: floats, tilts, flips (GPU transforms)
    Item {
        id: body
        width: root.dim.hgW
        height: root.dim.hgH
        x: (root.width - width) / 2
        y: root.height / 2 - 8 - height / 2 + root.floatY - turn.wildHop * 34
        transform: Scale {
            origin.x: body.width / 2
            origin.y: body.height
            xScale: 1 + 0.12 * turn.wildSquash
            yScale: 1 - 0.12 * turn.wildSquash
        }
        rotation: turn.flipAngle + Math.sin(clocks.floatClock * 0.85) * 1.6 * clocks.floatAmp / 5

        // Behind the glass: the sphere and the ring's inner face
        GotSlot {
            dim: root.dim
            active: root.gotStyle
            sourceComponent: GotBack {
                dim: root.dim
                gotColors: gotPalette
                frost: root.frost
                frostColor: root.frostColor
                frostStep: root.frostStep
            }
        }

        Glass {
            dim: root.dim
            level: sandLevel
            gotColors: gotPalette
            gotStyle: root.gotStyle
            ringing: root.ringing
            flowing: root.flowing
            frost: root.frost
            frostStep: root.frostStep
            frostColor: root.frostColor
            sandColor: root.sandColor
            glassColor: root.glassColor
            capColor: root.capColor
        }

        SandStream {
            flowing: root.flowing
            dim: root.dim
            fallLength: sandLevel.fallLength
            clock: clocks.clock
            frost: root.frost
            sandColor: root.sandColor
            frostColor: root.frostColor
        }

        // In front of the glass: the gold band, caps and sphere rim
        GotSlot {
            dim: root.dim
            active: root.gotStyle
            sourceComponent: GotFront {
                dim: root.dim
                gotColors: gotPalette
                bulbL: root.dim.bulbL
                frost: root.frost
                frostColor: root.frostColor
                frostStep: root.frostStep
            }
        }
    }
}
