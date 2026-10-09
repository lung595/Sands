import QtQuick
import "Colors.js" as Colors
import "FrostDraw.js" as FrostDraw
import "Geometry.js" as Geometry

// The glass, the sand in both bulbs, the frost and the bases, drawn in one
// canvas that is repainted only when the look changes (the sand moved by a
// visible amount, a colour or a freeze step changed).
Canvas {
    id: root

    required property var dim
    required property SandLevel level
    required property GotPalette gotColors
    required property bool gotStyle
    required property bool ringing
    // The sand is falling: the top sand shows its dip.
    required property bool flowing
    required property real frost
    required property int frostStep
    required property color frostColor
    required property color sandColor
    required property color glassColor
    required property color capColor

    anchors.fill: parent
    renderTarget: Canvas.FramebufferObject

    // Repaint only when the look changes.
    Connections {
        target: root.level
        function onTopPxChanged() {
            root.requestPaint();
        }
        function onBottomPxChanged() {
            root.requestPaint();
        }
    }
    onSandColorChanged: requestPaint()
    onFrostStepChanged: requestPaint()
    onFlowingChanged: requestPaint()
    onGotStyleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const L = dim.bulbL, R = dim.bulbR, n = dim.neck, capH = dim.capH, capW = dim.hgW;
        const profile = u => Geometry.profile(dim, u);
        const outline = () => Geometry.outline(ctx, dim);
        const white = Qt.rgba(1, 1, 1, 1);
        const sand = Colors.mix(sandColor, frostColor, frost * 0.55);
        const sandLight = Colors.mix(sand, white, 0.28);
        const sandDark = Colors.mix(sand, Qt.rgba(0, 0, 0, 1), 0.22);
        ctx.translate(width / 2, height / 2);

        // Glass
        outline();
        let g = ctx.createLinearGradient(-R, 0, R, 0);
        const tint = gotStyle ? Colors.mix(gotColors.mint, frostColor, frost * 0.5) : glassColor;
        g.addColorStop(0, Colors.rgba(tint, (gotStyle ? 0.16 : 0.07) + 0.06 * frost));
        g.addColorStop(0.5, Colors.rgba(tint, (gotStyle ? 0.08 : 0.025) + 0.04 * frost));
        g.addColorStop(1, Colors.rgba(tint, (gotStyle ? 0.14 : 0.06) + 0.06 * frost));
        ctx.fillStyle = g;
        ctx.fill();

        ctx.save();
        outline();
        ctx.clip();

        // Top sand, with a dip in the middle while it flows (or frozen).
        if (level.shownProgress > 0.0005) {
            const u = level.topU, yS = -(1 - u) * L;
            const dip = level.shownProgress < 0.995 && !ringing ? Math.min(L * 0.1, (1 - u) * L * 0.5) : 0;
            const dw = profile(u) * 0.55;
            ctx.beginPath();
            ctx.moveTo(-R - 2, n);
            ctx.lineTo(-R - 2, yS);
            ctx.lineTo(-dw, yS);
            ctx.quadraticCurveTo(0, yS + dip * 2, dw, yS);
            ctx.lineTo(R + 2, yS);
            ctx.lineTo(R + 2, n);
            ctx.closePath();
            g = ctx.createLinearGradient(0, yS, 0, 0);
            g.addColorStop(0, sandLight);
            g.addColorStop(1, sandDark);
            ctx.fillStyle = g;
            ctx.fill();
        }

        // Bottom sand: mound
        if (level.shownProgress < 0.9995) {
            const u = level.bottomU, rB = profile(u), m = level.moundH;
            const flat = (1 - u) * L + m * 0.35;
            ctx.beginPath();
            ctx.moveTo(-R - 2, L + 2);
            for (let i = 0; i <= 28; i++) {
                const x = -R - 2 + (2 * R + 4) * i / 28;
                ctx.lineTo(x, flat - m * Math.exp(-Math.pow(x / (rB * 0.62), 2)));
            }
            ctx.lineTo(R + 2, L + 2);
            ctx.closePath();
            g = ctx.createLinearGradient(0, flat - m, 0, L);
            g.addColorStop(0, sandLight);
            g.addColorStop(1, sandDark);
            ctx.fillStyle = g;
            ctx.fill();
        }

        // Frost inside the glass: cold veil + crystals on the walls
        if (frost > 0.01) {
            ctx.fillStyle = Colors.rgba(frostColor, 0.2 * frost);
            ctx.fillRect(-R - 4, -L - 4, 2 * R + 8, 2 * L + 8);
            ctx.strokeStyle = Colors.rgba(frostColor, 0.7 * frost);
            ctx.lineWidth = 0.8;
            for (let i = 0; i < 14; i++) {
                const s = Math.sin(i * 12.9898) * 43758.5453, h = s - Math.floor(s);
                const s2 = Math.sin(i * 78.233) * 12543.1, h2 = s2 - Math.floor(s2);
                const y = (h * 2 - 1) * L * 0.92;
                const side = i % 2 ? 1 : -1;
                const x = side * profile(1 - Math.abs(y) / L) * 0.94;
                FrostDraw.star(ctx, x, y, (3 + h2 * 5) * frost, h2);
            }
        }
        ctx.restore();

        // Outline + highlights
        outline();
        if (gotStyle) {
            ctx.lineWidth = Math.max(2, capW * 0.03);
            ctx.strokeStyle = Colors.rgba(Colors.mix(gotColors.teal, frostColor, frost * 0.5), 1);
        } else {
            ctx.lineWidth = 1.4;
            ctx.strokeStyle = Colors.rgba(Colors.mix(glassColor, frostColor, frost), 0.3 + 0.35 * frost);
        }
        ctx.stroke();

        ctx.lineCap = "round";
        ctx.lineWidth = Math.max(1.6, capW * 0.022);
        for (let s = -1; s <= 1; s += 2) {
            ctx.strokeStyle = Colors.rgba(glassColor, s < 0 ? 0.32 : 0.18);
            ctx.beginPath();
            for (let i = 0; i <= 12; i++) {
                const u = s < 0 ? 0.14 + 0.4 * i / 12 : 0.12 + 0.3 * i / 12;
                ctx.lineTo(-profile(u) * 0.74, s * (1 - u) * L);
            }
            ctx.stroke();
        }

        // Bases, with an accent rim on the glass side (Glass of Time
        // draws its own gold caps in front, see GotFront)
        for (let s = -1; s <= 1 && !gotStyle; s += 2) {
            const y = s < 0 ? -L - capH : L;
            g = ctx.createLinearGradient(0, y, 0, y + capH);
            g.addColorStop(0, Colors.mix(Colors.mix(capColor, white, 0.12), frostColor, frost * 0.3));
            g.addColorStop(1, Colors.mix(capColor, frostColor, frost * 0.2));
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.roundedRect(-capW / 2, y, capW, capH, capH / 2, capH / 2);
            ctx.fill();
            ctx.fillStyle = Colors.rgba(sand, 0.75);
            ctx.fillRect(-capW / 2 + capH, s < 0 ? y + capH - 1.5 : y, capW - capH * 2, 1.5);

            // Frost settling on the base: an uneven deposit, like rime on a ledge.
            if (frost > 0.01) {
                ctx.fillStyle = Colors.rgba(frostColor, 0.85 * frost);
                FrostDraw.rime(ctx, s, -capW / 2 + capH * 0.4, capW - capH * 0.8, s < 0 ? y : y + capH, 22, frost);
            }
        }
    }
}
