.pragma library

// Draws the texture of one sand layer into a Canvas 2D context. Colour alone
// never tells two layers apart (one strong colour only): the texture does.
// `kind` is Journal.textureOf(i); (x, y, w, h) is the area to fill.
function paint(ctx, kind, x, y, w, h, fg, bg) {
    ctx.save();
    ctx.beginPath();
    ctx.rect(x, y, w, h);
    ctx.clip();
    if (kind === 1) {
        // Light base with small holes
        ctx.globalAlpha = 0.72;
        ctx.fillStyle = fg;
        ctx.fillRect(x, y, w, h);
        ctx.globalAlpha = 1;
        dots(ctx, x, y, w, h, 1, bg);
    } else if (kind === 2) {
        // Diagonal hatching on a grid of 6
        ctx.strokeStyle = fg;
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (let d = x - h; d < x + w + 6; d += 6) {
            ctx.moveTo(d, y + h);
            ctx.lineTo(d + h, y);
        }
        ctx.stroke();
    } else if (kind === 3) {
        // Horizontal stripes: 2 on, 2 off
        ctx.fillStyle = fg;
        for (let r = y; r < y + h; r += 4)
            ctx.fillRect(x, r, w, 2);
    } else if (kind === 4) {
        dots(ctx, x, y, w, h, 1.5, fg);
    } else {
        ctx.fillStyle = fg;
        ctx.fillRect(x, y, w, h);
    }
    ctx.restore();
}

// Round dots of radius `r` on a grid of 6
function dots(ctx, x, y, w, h, r, color) {
    ctx.fillStyle = color;
    for (let cy = y + 3; cy < y + h + 3; cy += 6) {
        for (let cx = x + 3; cx < x + w + 3; cx += 6) {
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.fill();
        }
    }
}
