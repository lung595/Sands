.pragma library

// Tints of the Last grains dune, as pure colour maths on {r,g,b} (0..1).
// The caption sits on the sand, so a tint near it is held to a contrast floor.

// Share of the far colour a tint may reach freely, and the floor against the caption
const FREE = 0.55;
const FLOOR = 5;
// Shade of the four flat tints: deep shade, shade, the base itself, light
const LEVELS = [-1, -0.45, 0, 1];

function lin(v) {
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function lum(c) {
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

function ratio(a, b) {
    const x = lum(a), y = lum(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

function mix(a, b, t) {
    return { r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t };
}

// Largest share of `far` that keeps `caption` readable on the mixed colour
function capMix(base, far, caption) {
    let m = FREE;
    while (m > 0 && ratio(caption, mix(base, far, m)) < FLOOR)
        m -= 0.01;
    return Math.max(0, m);
}

// The four flat tints, plain and capped (for the rows behind the caption)
function tints(base, caption, text) {
    const pal = palette(base, caption, text);
    const build = lim => LEVELS.map(v => v > 0 ? mix(base, pal.lit, v * lim.lit) : mix(base, pal.dark, -v * lim.dark));
    return { plain: build(pal.free), capped: build(pal.capped) };
}

// Far colours and their free and capped limits, for continuous shading
function palette(base, caption, text) {
    const bright = lum(text) > lum(base);
    const capFar = capMix(base, caption, caption);
    return {
        base: base,
        lit: bright ? text : caption,
        dark: bright ? caption : text,
        free: { lit: FREE, dark: FREE },
        capped: { lit: bright ? FREE : capFar, dark: bright ? capFar : FREE }
    };
}

// Continuous tint for a shade `v` (-1 shaded .. 1 lit), as a CSS string; `capped`
// holds it to the caption contrast floor
function tone(pal, v, capped) {
    const lim = capped ? pal.capped : pal.free;
    return css(v > 0 ? mix(pal.base, pal.lit, v * lim.lit) : mix(pal.base, pal.dark, -v * lim.dark));
}

// Level index (0 deep shade .. 3 light) of a grain: `v` is -1 (shade) to 1 (lit)
function level(v) {
    return v < -0.62 ? 0 : v < -0.2 ? 1 : v < 0.45 ? 2 : 3;
}

// Lit and shaded faces from the slope of the surface (climbing to the right is
// lit), fading with depth, and darkening towards the foot of the dune.
// slope: surface height change per column share; depth: 0 at the skin, 1 deep.
function macro(slope, depth, foot) {
    const face = Math.max(-1, Math.min(1, 0.2 + slope * 0.9));
    return Math.max(-1, Math.min(1, face * Math.exp(-depth * 3) - 0.6 * Math.pow(Math.max(0, Math.min(1, foot)), 1.5)));
}

// Flat tints of the Flat wave cel. Rim: the base mixed toward the lighter of
// the two roles when that one can reach 3:1 against the base, the other one
// otherwise, the share raised from one half until 3:1 holds. Line: the base
// mixed toward the darker role. Speck: half the rim share.
function cel(base, caption, text) {
    const hi = lum(text) > lum(caption) ? text : caption, lo = hi === text ? caption : text;
    const far = ratio(hi, base) >= 3 ? hi : lo;
    let m = 0.5;
    while (m < 1 && ratio(mix(base, far, m), base) < 3)
        m += 0.01;
    m = Math.min(1, m);
    return { base: base, rim: mix(base, far, m), line: mix(base, lo, 0.3), speck: mix(base, far, m * 0.5), share: m };
}

function css(c) {
    return "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ")";
}
