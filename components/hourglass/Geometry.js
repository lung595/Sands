.pragma library

// Hourglass geometry and sand levels as pure functions (no QML, no state).
//
// Why: the sand follows time by VOLUME, so the bulb profile is integrated
// (cross-section ∝ radius²) to find the level that holds exactly the
// remaining fraction. Keeping this out of the QML makes it testable with gjs.

// Sizes (px) shared by the drawing and the falling grains. The Glass of Time
// style is a bit smaller so the sphere around it fits the panel.
function dimensions(width, height, gotStyle) {
    const hgH = gotStyle ? Math.min(height * 0.66, width * 0.68) : Math.min(height * 0.8, width * 1.2);
    const hgW = hgH * 0.6;
    const capH = Math.max(6, hgH * 0.05);
    const bulbL = hgH / 2 - capH - 1;
    return {
        hgH: hgH,
        hgW: hgW,
        capH: capH,
        bulbL: bulbL,
        bulbR: hgW / 2 - hgW * 0.07,
        neck: Math.max(2.2, hgW * 0.028),
        // Glass of Time: sphere radius (the gold caps are its top and bottom)
        sphereR: bulbL + capH * 2.4
    };
}

// Radius of the bulb at u (0 = neck, 1 = rim).
function profile(dim, u) {
    u = Math.max(0, Math.min(1, u));
    const shoulder = 0.8 + 0.2 * Math.sin(Math.min(1, u / 0.28) * Math.PI / 2);
    return dim.neck + (dim.bulbR - dim.neck) * Math.pow(1 - u * u, 1.45) * shoulder;
}

// Cumulative volume table, to rebuild only when the size changes.
function volumes(dim) {
    const N = 200, w = [];
    let total = 0;
    for (let k = 0; k <= N; k++) {
        const r = profile(dim, k / N);
        w.push(r * r);
        total += r * r;
    }
    return {
        N: N,
        w: w,
        total: total
    };
}

// Level u holding the fraction `frac`, filling from the neck (fromNeck) or
// from the rim.
function level(vol, frac, fromNeck) {
    const target = frac * vol.total;
    let acc = 0;
    for (let i = 0; i <= vol.N; i++) {
        const k = fromNeck ? vol.N - i : i;
        if (acc + vol.w[k] >= target) {
            const f = (target - acc) / vol.w[k];
            return Math.max(0, Math.min(1, (fromNeck ? k + 1 - f : k + f) / vol.N));
        }
        acc += vol.w[k];
    }
    return fromNeck ? 0 : 1;
}

// Everything the sand needs for a displayed fraction: both levels, the
// mound, and the length of the falling stream.
function sand(dim, vol, shown) {
    const topU = shown > 0.0005 ? level(vol, shown, true) : 1;
    const bottomU = shown < 0.9995 ? level(vol, 1 - shown, false) : 0;
    const moundH = Math.min(dim.bulbL * 0.16, (1 - bottomU) * dim.bulbL * 0.9) * Math.min(1, (1 - shown) * 6);
    return {
        topU: topU,
        bottomU: bottomU,
        moundH: moundH,
        // Top of the mound, from the neck: length of the falling grains.
        fallLength: Math.max(4, (1 - bottomU) * dim.bulbL + moundH * 0.35 - moundH - dim.neck)
    };
}

// Traces the closed outline of both bulbs on a 2D context centered on the
// neck (y up is negative): the left wall down and up, then the right wall.
function outline(ctx, dim) {
    const L = dim.bulbL, S = 40;
    ctx.beginPath();
    for (let i = 0; i <= S; i++)
        ctx.lineTo(-profile(dim, i / S), -(1 - i / S) * L);
    for (let i = S; i >= 0; i--)
        ctx.lineTo(-profile(dim, i / S), (1 - i / S) * L);
    for (let i = 0; i <= S; i++)
        ctx.lineTo(profile(dim, i / S), (1 - i / S) * L);
    for (let i = S; i >= 0; i--)
        ctx.lineTo(profile(dim, i / S), -(1 - i / S) * L);
    ctx.closePath();
}
