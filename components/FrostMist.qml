import QtQuick
import "Motion.js" as Motion

// Cold mist behind the hourglass. Drawn once; its slow drift follows the
// hourglass effects clock (fxTime, a 30 Hz Timer), not looping QML
// animations, which would redraw the whole shell (Motion.js).
Item {
    id: root

    required property real frost
    required property color frostColor
    required property bool reducedMotion
    required property real fxTime
    // Space the panel leaves above this item; the mist reaches up into it.
    required property real topInset

    anchors.fill: parent
    opacity: frost

    Canvas {
        id: mist
        // Full panel width, from the top of the panel to below
        // the clock: the mist passes behind the text (drawn afterwards,
        // so on top) instead of stopping under the hourglass.
        width: root.width
        height: 360
        x: baseX + (root.reducedMotion ? 0 : Motion.wave(root.fxTime, 18, -10, 10))
        y: baseY + (root.reducedMotion ? 0 : Motion.wave(root.fxTime, 13, -4, 6))
        opacity: root.reducedMotion ? 1 : Motion.wave(root.fxTime, 10, 1, 0.8)
        renderTarget: Canvas.FramebufferObject
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = root.frostColor;
            // Overlapping cold clouds: a mist, not a circle.
            // In canvas pixels (340 × 360, hourglass centered around y = 118);
            // each cloud fits entirely in the canvas and fades out before
            // its edge: no seam, with no mask (Qt does not support
            // "destination-in"). [x, y, radius, opacity at the center]
            const blobs = [[170, 130, 124, 0.34], [120, 95, 80, 0.22], [220, 100, 84, 0.2], [125, 190, 80, 0.2], [215, 195, 84, 0.22], [170, 250, 100, 0.2], [170, 62, 56, 0.16]];
            const sx = width / 340;
            for (const b of blobs) {
                const x = b[0] * sx, y = b[1], r = b[2];
                const g = ctx.createRadialGradient(x, y, 0, x, y, r);
                g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, b[3]));
                g.addColorStop(0.5, Qt.rgba(c.r, c.g, c.b, b[3] * 0.4));
                g.addColorStop(0.75, Qt.rgba(c.r, c.g, c.b, b[3] * 0.12));
                g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                ctx.fillStyle = g;
                // Only the cloud's square: beyond it, it is transparent.
                ctx.fillRect(x - r, y - r, 2 * r, 2 * r);
            }
        }

        // The mist floats gently in the background: drifts sideways,
        // rises and falls, breathes. Different periods (18 s, 13 s,
        // 10 s): the motion never quite repeats. Amplitudes chosen so
        // the clouds stay inside the panel.
        readonly property real baseX: (root.width - width) / 2
        readonly property real baseY: -root.topInset
    }
}
