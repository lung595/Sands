import QtQuick

// Cold halo behind the clock (drawn once, the frost level fades it).
Canvas {
    id: root

    required property real frost
    required property color frostColor

    width: 220
    height: 90
    opacity: frost
    renderTarget: Canvas.FramebufferObject
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const c = root.frostColor;
        ctx.translate(width / 2, height / 2);
        ctx.scale(1, height / width);
        const g = ctx.createRadialGradient(0, 0, 0, 0, 0, width / 2);
        g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.26));
        g.addColorStop(0.6, Qt.rgba(c.r, c.g, c.b, 0.07));
        g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(0, 0, width / 2, 0, Math.PI * 2);
        ctx.fill();
    }
}
