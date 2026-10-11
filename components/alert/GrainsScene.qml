import QtQuick
import qs.Common
import "DuneMotion.js" as Motion
import "SandTint.js" as Tint

// Option A "Last grains": the falling thread, the heap and the grains rolling
// ahead of the two fronts, drawn from the state DuneMotion gives for the
// current step. Matte on purpose: flat tints, no gloss and no highlight.
// The Canvas only repaints when the host hands it a new state, so once the
// timer has stopped nothing is drawn again.
Canvas {
    id: scene

    // State of the current step (DuneMotion.stateAt)
    property var duneState: Motion.posed("grains")
    // Run seed, so the speckle of one alert is the same on every repaint
    property int seed: 1

    // Share of the band the posed crest may reach; the rest is for the legend
    readonly property real reach: 0.62
    // Grain sizes 2 to 4 px; the count follows the area, capped for a wide screen
    readonly property int speckCount: Math.min(1500, Math.round(width * height / 160))

    // Caption box in scene coordinates: tints behind it are held to a contrast
    // floor against the on-primary caption (set by the band)
    property real capLeft: 0
    property real capRight: 0
    property real capTop: height

    // Four flat tints from Theme roles, plain and capped, as CSS strings
    readonly property var _sets: {
        const rgb = c => ({
                    r: c.r,
                    g: c.g,
                    b: c.b
                });
        const t = Tint.tints(rgb(Theme.primary), rgb(Theme.onPrimary), rgb(Theme.surfaceText));
        return {
            plain: t.plain.map(Tint.css),
            capped: t.capped.map(Tint.css)
        };
    }

    // The same colours as continuous shading, for the faces
    readonly property var _pal: Tint.palette({
        r: Theme.primary.r,
        g: Theme.primary.g,
        b: Theme.primary.b
    }, {
        r: Theme.onPrimary.r,
        g: Theme.onPrimary.g,
        b: Theme.onPrimary.b
    }, {
        r: Theme.surfaceText.r,
        g: Theme.surfaceText.g,
        b: Theme.surfaceText.b
    })

    property var _speck: []
    property string _speckKey: ""

    onDuneStateChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    on_SetsChanged: requestPaint()
    on_PalChanged: requestPaint()

    // Seeded grains, made again only when the size or the seed changes
    function _grains() {
        const key = width + "x" + height + ":" + seed;
        if (key === _speckKey)
            return _speck;
        const r = Motion.rng(seed), list = [];
        for (let i = 0; i < speckCount; i++)
            list.push({
                x: r(),
                y: r(),
                size: 2 + Math.floor(r() * 3),
                noise: r() - 0.5
            });
        _speck = list;
        _speckKey = key;
        return list;
    }

    // Surface y at share x of the width, linear between the column centres
    function _surface(heights, x) {
        const n = heights.length, p = Math.max(0, Math.min(n - 1, x * n - 0.5));
        const i = Math.floor(p), j = Math.min(n - 1, i + 1), f = p - i;
        return height - (heights[i] * (1 - f) + heights[j] * f) * height * reach;
    }

    // Whether a point lies in the caption band, where tints are capped
    function _inBand(x, y) {
        return y >= capTop - 4 && x >= capLeft - 4 && x <= capRight + 4;
    }

    // Plain or capped tints for a point
    function _tintsAt(x, y) {
        return _inBand(x, y) ? _sets.capped : _sets.plain;
    }

    // Shade (-1 .. 1) of the sand at x and y: the face from the local slope, the
    // depth under the skin and the share of the way down to the foot
    function _shade(heights, x, y, extra) {
        const top = _surface(heights, x), slope = (top - _surface(heights, Math.min(1, x + 0.01))) / height / 0.02 / reach;
        const depth = Math.max(0, y - top) / (height * reach), foot = (y - top) / Math.max(1, height - top);
        return Tint.macro(slope * 0.9, depth, foot) + extra;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const s = duneState, h = s.heights, n = h.length, sets = _sets;

        // Smooth outline: quadratic through the column centres
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(0, height);
        ctx.lineTo(0, _surface(h, 0));
        for (let i = 0; i < n - 1; i++) {
            const x0 = (i + 0.5) / n, x1 = (i + 1.5) / n;
            ctx.quadraticCurveTo(x0 * width, _surface(h, x0), (x0 + x1) / 2 * width, (_surface(h, x0) + _surface(h, x1)) / 2);
        }
        ctx.lineTo(width, _surface(h, 1));
        ctx.lineTo(width, height);
        ctx.closePath();
        ctx.fillStyle = sets.plain[2];
        ctx.fill();
        ctx.clip();

        // Faces: strips of eight depth rows, each tinted continuously from the local
        // slope (the dither of the loose grains below breaks the rows up)
        const strip = 4, rows = [0, 0.03, 0.08, 0.15, 0.25, 0.4, 0.6, 0.82];
        for (let x = 0; x < width; x += strip) {
            const sx = (x + strip / 2) / width, top = Math.floor(_surface(h, sx)), span = height - top;
            for (let b = 0; b < rows.length; b++) {
                const y = top + Math.floor(span * rows[b]), next = b < rows.length - 1 ? top + Math.floor(span * rows[b + 1]) : height;
                ctx.fillStyle = Tint.tone(_pal, _shade(h, sx, y, 0), _inBand(x, y));
                ctx.fillRect(x, y, strip, next - y + 1);
            }
        }

        // Speckle below the surface only; strata come from the noise
        const list = _grains();
        for (let k = 0; k < list.length; k++) {
            const g = list[k], px = Math.round(g.x * width), py = Math.round(g.y * height);
            if (py < _surface(h, g.x))
                continue;
            ctx.fillStyle = _tintsAt(px, py)[Tint.level(_shade(h, g.x, py, g.noise * 1.1))];
            ctx.fillRect(px, py, g.size, g.size);
        }
        ctx.restore();

        // The thread falls from the top edge while the heap grows under it
        const t = s.step / Motion.STEP_HZ;
        if (!s.done && t < 1.5) {
            const top = _surface(h, 0.5), cx = Math.round(width / 2);
            ctx.fillStyle = sets.plain[2];
            ctx.fillRect(cx - 1, 0, 2, Math.min(top, height * Math.min(1, t / 0.4)));
        }

        // Loose grains: y is a share of the band height above the floor
        ctx.fillStyle = sets.plain[3];
        for (const g of s.grains)
            ctx.fillRect(Math.round(g.x * width), Math.round(height - g.y * height * reach - 3), 3, 3);
    }
}
