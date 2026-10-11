import QtQuick
import "DuneMotion.js" as Motion
import "SandTint.js" as Tint

// Option B "Wind dune": the same matte sand as Last grains, blown in from the
// left edge. The front, its travelling crest and the hopping grains come from
// the state DuneMotion gives for the current step; no thread falls, and the
// loose grains ride the sand, so the last ones slide down the steep face.
// Nothing here repaints by itself: one paint per state handed by the band.
GrainsScene {
    id: scene

    duneState: Motion.posed("wind")
    thread: false
    grainsRide: true

    // Runs after the sand is painted: a 1 px lit edge along the windward
    // slope, up to the crest, once the dune has its final shape (from 1.5 s).
    // It stays out of the caption band.
    onPaint: {
        const s = duneState, t = s.step / Motion.STEP_HZ;
        const a = s.done ? 1 : Motion.smooth((t - 1.5) / 0.4);
        if (a <= 0)
            return;
        const ctx = getContext("2d"), end = s.crest * width;
        let pen = false;
        ctx.save();
        ctx.globalAlpha = a;
        ctx.strokeStyle = Tint.tone(_pal, 1, false);
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let x = 0; x <= end; x += 2) {
            const y = _surface(s.heights, x / width) + 0.5;
            if (_inBand(x, y + 6)) {
                pen = false;
                continue;
            }
            if (pen)
                ctx.lineTo(x, y);
            else
                ctx.moveTo(x, y);
            pen = true;
        }
        ctx.stroke();
        ctx.restore();
    }
}
