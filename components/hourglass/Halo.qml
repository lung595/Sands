import QtQuick
import "Colors.js" as Colors

// A soft radial glow, drawn once and animated through opacity.
Canvas {
    id: root

    required property color tint
    // Glass of Time: a softer, longer falloff.
    required property bool gotStyle
    // Diameter (px).
    required property real size

    anchors.centerIn: parent
    width: size
    height: width
    renderTarget: Canvas.FramebufferObject
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onGotStyleChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const r = width / 2;
        const g = ctx.createRadialGradient(r, r, 0, r, r, r);
        g.addColorStop(0, Colors.rgba(tint, 0.5));
        if (gotStyle) {
            // Gone at 66% of the radius, i.e. at the panel's edge, so it
            // never ends on a hard line
            g.addColorStop(0.3, Colors.rgba(tint, 0.4));
            g.addColorStop(0.45, Colors.rgba(tint, 0.22));
            g.addColorStop(0.56, Colors.rgba(tint, 0.08));
            g.addColorStop(0.66, Colors.rgba(tint, 0));
        } else {
            g.addColorStop(0.45, Colors.rgba(tint, 0.16));
        }
        // Fades out at 85% of the radius: even enlarged, the aura stays inside the
        // panel (DMS clips whatever overflows, which would leave a hard edge).
        g.addColorStop(0.85, Colors.rgba(tint, 0));
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, width, height);
    }
}
