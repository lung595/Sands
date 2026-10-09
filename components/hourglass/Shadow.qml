import QtQuick

// Ground shadow: tightens and fades when the hourglass rises.
Canvas {
    id: root

    required property real hgW
    required property real hgH
    // Vertical offset (px) of the floating hourglass, -5..5.
    required property real floatY
    required property color shadowColor

    width: hgW
    height: hgW * 0.2
    x: (parent.width - width) / 2
    y: parent.height / 2 - 8 + hgH / 2 + 16 - height / 2
    scale: 0.9 + 0.08 * (floatY + 5) / 10
    opacity: 0.85 - 0.25 * (floatY + 5) / 10
    renderTarget: Canvas.FramebufferObject
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.save();
        ctx.translate(width / 2, height / 2);
        ctx.scale(1, height / width);
        const g = ctx.createRadialGradient(0, 0, 0, 0, 0, width / 2);
        g.addColorStop(0, Qt.rgba(shadowColor.r, shadowColor.g, shadowColor.b, 0.4));
        g.addColorStop(1, Qt.rgba(shadowColor.r, shadowColor.g, shadowColor.b, 0));
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(0, 0, width / 2, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}
