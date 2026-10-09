.pragma library

// Frost shapes drawn on a 2D context. No colours here (the caller sets the
// stroke and fill styles first), so the module needs no QML and is tested.

// A six-armed ice crystal centered on (x, y); `phase` turns it.
function star(ctx, x, y, size, phase) {
    for (let a = 0; a < 6; a++) {
        const ang = a * Math.PI / 3 + phase;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + Math.cos(ang) * size, y + Math.sin(ang) * size);
        ctx.stroke();
    }
}

// Rime settling on a ledge: `count` uneven drops spread over `span` from x0,
// sitting on the edge at edgeY. `side` (-1 top, 1 bottom) varies the pattern
// between the two ledges; `frost` (0..1) grows the drops.
function rime(ctx, side, x0, span, edgeY, count, frost) {
    for (let i = 0; i < count; i++) {
        const hh = Math.abs(Math.sin((i + side * 7) * 43.13) * 9127.3) % 1;
        const bx = x0 + span * (i + 0.5) / count;
        const br = (1 + hh * 2.2) * frost;
        ctx.beginPath();
        ctx.ellipse(bx - br, edgeY - br * 0.7, br * 2, br * 1.4);
        ctx.fill();
    }
}
