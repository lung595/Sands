.pragma library

// Colour helpers for the canvases. They live here, not in each canvas,
// so every layer mixes and fades colours the same way.

function rgba(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
}

// Opaque blend of c1 toward c2 by t (0..1).
function mix(c1, c2, t) {
    return Qt.rgba(c1.r + (c2.r - c1.r) * t, c1.g + (c2.g - c1.g) * t, c1.b + (c2.b - c1.b) * t, 1);
}
