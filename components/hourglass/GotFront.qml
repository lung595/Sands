import QtQuick
import "Colors.js" as Colors
import "FrostDraw.js" as FrostDraw

// Glass of Time, in front of the glass: the gold band, the gold caps with
// their mint rim, the sphere rim and, when frozen, its rime crown.
GotLayer {
    // Length (px) of a bulb: the caps sit at its two ends.
    required property real bulbL

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.translate(width / 2, height / 2);
        const S = dim.sphereR, L = bulbL;
        const cold = (c, k) => Colors.mix(c, frostColor, frost * k);
        const line = Colors.rgba(cold(gotColors.goldLine, 0.4), 1);
        const lw = Math.max(1.5, S * 0.012);
        const chord = Math.sqrt(Math.max(0, S * S - L * L));

        // Gold band: between the upper arcs of the ring's two edges
        function upperArc(cy, fromLeft) {
            for (let i = 0; i <= 40; i++) {
                const t = fromLeft ? i / 40 : 1 - i / 40;
                const a = Math.PI + t * Math.PI;
                ctx.lineTo(Math.cos(a) * ringRx, cy + Math.sin(a) * ringRy);
            }
        }
        ctx.beginPath();
        upperArc(ringTop, true);
        upperArc(ringBottom, false);
        ctx.closePath();
        ctx.fillStyle = cold(gotColors.gold, 0.5);
        ctx.fill();
        // Lit facet on the band
        ctx.save();
        ctx.clip();
        ctx.fillStyle = cold(gotColors.goldLight, 0.5);
        ctx.fillRect(-S * 0.42, -S, S * 0.42, S * 2);
        ctx.restore();
        ctx.beginPath();
        upperArc(ringTop, true);
        upperArc(ringBottom, false);
        ctx.closePath();
        ctx.lineWidth = lw;
        ctx.strokeStyle = line;
        ctx.stroke();

        // Caps: the sphere's top and bottom in gold, a mint rim of
        // glass just inside each
        for (let s = -1; s <= 1; s += 2) {
            ctx.save();
            ctx.beginPath();
            ctx.arc(0, 0, S, 0, Math.PI * 2);
            ctx.clip();
            const y0 = s < 0 ? -S : L;
            const g = ctx.createLinearGradient(-S, 0, S, 0);
            g.addColorStop(0, cold(gotColors.goldLight, 0.4));
            g.addColorStop(0.55, cold(gotColors.gold, 0.4));
            g.addColorStop(1, cold(gotColors.gold, 0.4));
            ctx.fillStyle = g;
            ctx.fillRect(-S, y0, S * 2, S - L);
            ctx.restore();
            ctx.beginPath();
            ctx.ellipse(-chord, s * L - S * 0.05, chord * 2, S * 0.1);
            ctx.fillStyle = Colors.rgba(cold(gotColors.mint, 0.5), 0.85);
            ctx.fill();
            ctx.lineWidth = lw;
            ctx.strokeStyle = line;
            ctx.beginPath();
            ctx.moveTo(-chord, s * L);
            ctx.lineTo(chord, s * L);
            ctx.stroke();
            // Rime settling on the cap, as on the classic bases
            if (frost > 0.01) {
                ctx.fillStyle = Colors.rgba(frostColor, 0.85 * frost);
                FrostDraw.rime(ctx, s, -chord * 0.9, chord * 1.8, s * L, 18, frost);
            }
        }

        // Sphere rim
        ctx.beginPath();
        ctx.arc(0, 0, S, 0, Math.PI * 2);
        ctx.lineWidth = Math.max(2, S * 0.018);
        ctx.strokeStyle = Colors.rgba(cold(gotColors.sphere, 0.5), 0.95);
        ctx.stroke();

        // Frozen: a rime crown on the sphere, crystals poking out
        if (frost > 0.01) {
            ctx.beginPath();
            ctx.arc(0, 0, S, 0, Math.PI * 2);
            ctx.lineWidth = Math.max(3, S * 0.05) * frost;
            ctx.strokeStyle = Colors.rgba(frostColor, 0.45 * frost);
            ctx.stroke();
            ctx.strokeStyle = Colors.rgba(frostColor, 0.8 * frost);
            ctx.lineWidth = 0.9;
            for (let i = 0; i < 28; i++) {
                const h = Math.abs(Math.sin(i * 12.9898) * 43758.5453) % 1;
                const a = (i + h * 0.6) / 28 * Math.PI * 2;
                FrostDraw.star(ctx, Math.cos(a) * S, Math.sin(a) * S, (2.5 + h * 4) * frost, h);
            }
        }
    }
}
