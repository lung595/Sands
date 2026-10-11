import QtQuick
import qs.Common
import "DuneMotion.js" as Motion
import "SandTint.js" as Tint

// Option C "Flat wave": one flat cartoon ridge in the primary colour, a rim
// along its crest, a base line on the long slope, sand specks under the skin,
// eight round grains that hop off the crest at the overshoot and the fine sand
// thrown at each thud. The body (rise, overshoot, three beats, lean) comes from
// the state DuneMotion gives for the current step. Flat tints only, no gloss.
// One paint per state handed by the band, so nothing is drawn once it stops.
Canvas {
    id: scene

    // State of the current step (DuneMotion.stateAt)
    property var duneState: Motion.posed("wave")
    // Run seed: the specks and the round grains of one alert stay the same
    property int seed: 1

    // Share of the band the posed crest reaches: tall enough that the deepest
    // squash still leaves the caption on the wave, low enough for the overshoot
    readonly property real reach: 0.8
    readonly property int speckCount: Math.min(160, Math.round(width / 5))
    readonly property int roundCount: 8

    // Caption box in scene coordinates: specks stay out of it (set by the band)
    property real capLeft: 0
    property real capRight: 0
    property real capTop: height

    // Tints from Theme roles, as CSS strings
    readonly property var _pal: {
        const rgb = c => ({
                    r: c.r,
                    g: c.g,
                    b: c.b
                });
        const c = Tint.cel(rgb(Theme.primary), rgb(Theme.onPrimary), rgb(Theme.surfaceText));
        return {
            base: Tint.css(c.base),
            rim: Tint.css(c.rim),
            line: Tint.css(c.line),
            speck: Tint.css(c.speck)
        };
    }

    property var _parts: null
    property string _partsKey: ""
    // Outline of the current paint: x and y in px, x rising
    property var _px: []
    property var _py: []

    onDuneStateChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    on_PalChanged: requestPaint()

    // Seeded specks, round grains and slides, made again only when the size or
    // the seed changes. Lengths are shares of the width or of the wave height.
    function _seeded() {
        const key = width + "x" + height + ":" + seed;
        if (key === _partsKey && _parts)
            return _parts;
        const r = Motion.rng(seed), speck = [], round = [], slide = [], c = duneState.crest;
        for (let i = 0; i < speckCount; i++)
            speck.push({
                x: r(),
                d: r() * r() * 0.36,
                size: r() < 0.7 ? 2 : 3,
                lit: r() < 0.55
            });
        for (let i = 0; i < roundCount; i++) {
            const g = {
                x: c - 0.24 + 0.5 * (i + r()) / roundCount,
                r: 3 + r(),
                dx: (r() - 0.5) * 0.42,
                hop: 0.36 + r() * 0.48,
                at: 0.5 + r() * 0.08,
                d: 0.34 + r() * 0.12,
                roll: 0
            };
            // Three of them do not stay: they land, then roll down away from the crest
            const far = 0.4 + r() * 0.27;
            if (i === 1 || i === 4 || i === 6)
                g.roll = (g.x < c ? -1 : 1) * far;
            round.push(g);
        }
        // Grains that trickle down the slip face while the dune builds back
        for (let i = 0; i < 7; i++)
            slide.push({
                t: 0.75 + r() * 0.8,
                x: c + 0.02 + r() * 0.1,
                dist: 0.1 + r() * 0.14,
                d: 0.4 + r() * 0.3
            });
        _parts = {
            speck,
            round,
            slide
        };
        _partsKey = key;
        return _parts;
    }

    // Height (share of the reach) at share u of the width: a smooth curve
    // through the column centres, flat past the first and the last one
    function _heightAt(heights, u) {
        const n = heights.length, p = Math.max(0, Math.min(n - 1, u * n - 0.5));
        const i = Math.floor(p), f = p - i, at = k => heights[Math.max(0, Math.min(n - 1, k))];
        const a = at(i - 1), b = at(i), c = at(i + 1), d = at(i + 2);
        return b + 0.5 * f * (c - a + f * (2 * a - 5 * b + 4 * c - d + f * (3 * (b - c) + d - a)));
    }

    // The outline of this step: every point is pushed toward the crest side
    // by its own height times the lean (one shear step)
    function _outline(s) {
        const hd = height * reach, count = Math.max(24, Math.ceil(width / 6)), xs = [], ys = [];
        for (let k = 0; k <= count; k++) {
            const u = -0.2 + 1.4 * k / count, h = _heightAt(s.heights, u) * hd;
            xs.push(u * width + s.lean * h);
            ys.push(height - h);
        }
        _px = xs;
        _py = ys;
    }

    // Surface y at x px, read from the outline of this step
    function _surface(x) {
        const xs = _px, ys = _py;
        let lo = 0, hi = xs.length - 1;
        if (x <= xs[0])
            return ys[0];
        if (x >= xs[hi])
            return ys[hi];
        while (hi - lo > 1) {
            const mid = (lo + hi) >> 1;
            if (xs[mid] <= x)
                lo = mid;
            else
                hi = mid;
        }
        return ys[lo] + (ys[hi] - ys[lo]) * (x - xs[lo]) / Math.max(0.001, xs[hi] - xs[lo]);
    }

    function _trace(ctx, dy, from, to) {
        for (let k = 0; k < _px.length; k++) {
            if (_px[k] < from || _px[k] > to)
                continue;
            ctx.lineTo(_px[k], _py[k] + dy);
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const s = duneState, pal = _pal, parts = _seeded(), hd = height * reach;
        const t = s.step / Motion.STEP_HZ, wide = 1 / (1 - Math.min(0.5, s.squash));
        _outline(s);

        // The flat shape
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(_px[0], height);
        _trace(ctx, 0, -Infinity, Infinity);
        ctx.lineTo(_px[_px.length - 1], height);
        ctx.closePath();
        ctx.fillStyle = pal.base;
        ctx.fill();
        ctx.clip();

        // Rim: the inner half of a stroke clipped to the wave, 3 px at rest and
        // thicker while the wave is squashed; the base line 1 px under it on the
        // long slope only
        ctx.beginPath();
        _trace(ctx, 0, -Infinity, Infinity);
        ctx.strokeStyle = pal.rim;
        ctx.lineWidth = 6 * wide;
        ctx.stroke();
        ctx.beginPath();
        _trace(ctx, 3 * wide + 0.5, -Infinity, (s.crest - 0.2) * width);
        ctx.strokeStyle = pal.line;
        ctx.lineWidth = 1;
        ctx.stroke();

        // Specks ride the surface and stay out of the caption band
        for (const q of parts.speck) {
            const x = Math.round(q.x * width), y = Math.round(_surface(x) + 6 + q.d * hd * wide);
            if (y + q.size > height || (y + q.size > capTop - 6 && x + q.size > capLeft - 6 && x < capRight + 6))
                continue;
            ctx.fillStyle = q.lit ? pal.speck : pal.line;
            ctx.fillRect(x, y, q.size, q.size);
        }
        ctx.restore();

        if (!s.done) {
            // Fine sand thrown off the crest, gone when it lands
            ctx.fillStyle = pal.base;
            for (let k = 0; k < s.grains.length; k++) {
                const g = s.grains[k], x = g.x * width, size = 2 + k % 2;
                ctx.fillRect(Math.round(x), Math.round(_surface(x) - size - g.y * hd), size, size);
            }
            for (const q of parts.slide) {
                const v = (t - q.t) / q.d;
                if (v < 0 || v > 1)
                    continue;
                const x = (q.x + q.dist * v * (2 - v)) * width;
                ctx.fillRect(Math.round(x), Math.round(_surface(x) - 2), 3, 3);
            }
        }

        // Round grains: a flat disc and a flat dot of the rim tint
        for (const q of parts.round) {
            if (!s.done && t < q.at)
                continue;
            const v = s.done ? 1 : Motion.clamp((t - q.at) / q.d);
            const v2 = q.roll === 0 ? 0 : s.done ? 1 : Motion.clamp((t - q.at - q.d) / 0.7);
            const x = q.x * width + (q.dx * v + q.roll * v2 * v2) * hd;
            const y = _surface(x) - q.r + 1 - q.hop * hd * 4 * v * (1 - v) - 0.08 * hd * Math.abs(Math.sin(2 * Math.PI * v2)) * (1 - v2);
            ctx.beginPath();
            ctx.arc(x, y, q.r, 0, 2 * Math.PI);
            ctx.fillStyle = pal.base;
            ctx.fill();
            ctx.beginPath();
            ctx.arc(x - q.r * 0.3, y - q.r * 0.3, q.r * 0.45, 0, 2 * Math.PI);
            ctx.fillStyle = pal.rim;
            ctx.fill();
        }
    }
}
