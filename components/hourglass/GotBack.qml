import QtQuick
import "Colors.js" as Colors

// Glass of Time, behind the glass: the translucent sphere and the inner face
// of the ring, seen through the glass.
GotLayer {
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.translate(width / 2, height / 2);
        const S = dim.sphereR;
        const cold = (c, k) => Colors.mix(c, frostColor, frost * k);
        // Translucent sphere
        const g = ctx.createRadialGradient(-S * 0.3, -S * 0.35, S * 0.1, 0, 0, S);
        g.addColorStop(0, Colors.rgba(cold(gotColors.sphere, 0.5), 0.16));
        g.addColorStop(1, Colors.rgba(cold(gotColors.sphere, 0.5), 0.34));
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(0, 0, S, 0, Math.PI * 2);
        ctx.fill();
        // Inner face of the ring, seen through the glass
        ctx.beginPath();
        ctx.ellipse(-ringRx, ringBottom - ringRy, ringRx * 2, ringRy * 2);
        ctx.fillStyle = Colors.rgba(cold(gotColors.olive, 0.5), 0.95);
        ctx.fill();
        ctx.lineWidth = Math.max(1.5, S * 0.012);
        ctx.strokeStyle = Colors.rgba(cold(gotColors.goldLine, 0.4), 1);
        ctx.stroke();
    }
}
