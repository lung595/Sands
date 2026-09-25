import QtQuick

// Floating hourglass.
//
// Light by design: the glass and the sand are drawn in a Canvas
// that only repaints when the level changes (≈ once per second); everything
// that moves every frame (float, tilt, flip, grains) is
// a plain item transform, done by the GPU, with no repaint.
//
// The sand follows time by VOLUME: the bulb profile is integrated
// (cross-section ∝ radius²) to find the level that holds exactly the
// remaining fraction.
//
// - progress : remaining fraction at the top (1 = full, 0 = empty)
// - frost    : 0 → 1, freeze (driven by the panel, which freezes the whole screen)
// - flip()   : the hourglass turns over (when restarting)
Item {
    id: root

    property real progress: 1
    property bool running: true
    property bool paused: false
    property bool ringing: false
    property real frost: 0
    // false when the panel is closed: no frame is computed anymore.
    property bool animate: true
    // DMS "reduce motion" setting: no floating and no flipping.
    property bool reducedMotion: false

    property color sandColor: "#e0b050"
    property color glassColor: "white"
    property color capColor: "#2a2a2a"
    property color frostColor: Qt.rgba(0.8, 0.9, 1, 1)
    property color shadowColor: "black"

    implicitWidth: 220
    implicitHeight: 250

    // --- Motion clock: slows down to a stop when freezing.
    property real speed: (paused || !running) ? 0 : 1
    Behavior on speed {
        NumberAnimation {
            duration: 900
            easing.type: Easing.OutCubic
        }
    }
    property real clock: 0

    // Floating: never stops. Frozen, it slows down and tightens,
    // as at absolute zero: almost still, but not quite.
    property real floatClock: 0
    property real floatSpeed: paused ? 0.3 : 1
    property real floatAmp: reducedMotion ? 0 : (paused ? 1.6 : 5)
    Behavior on floatSpeed {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on floatAmp {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.InOutCubic
        }
    }

    FrameAnimation {
        running: root.visible && root.animate
        onTriggered: {
            root.floatClock += frameTime * root.floatSpeed;
            if (root.speed > 0.001)
                root.clock += frameTime * root.speed;
        }
    }

    // Displayed sand: follows `progress` smoothly, but jumps at once on
    // a big change (restart: the flip is what animates).
    property real shownProgress: progress
    Behavior on shownProgress {
        // Smoothed only for a real visible jump (+1 min, short timer);
        // neither for an invisible step nor for a flip (> 50%).
        enabled: Math.abs(root.progress - root.shownProgress) < 0.5 && Math.abs(root.progress - root.shownProgress) > 0.004
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    // Flip: the new state (top full) starts upside down and rotates
    // back upright, like a real hourglass being turned over.
    property real flipAngle: 0
    function flip() {
        if (!root.reducedMotion && root.animate)
            flipAnim.restart();
    }
    NumberAnimation {
        id: flipAnim
        target: root
        property: "flipAngle"
        from: 180
        to: 360
        duration: 850
        easing.type: Easing.InOutBack
        easing.overshoot: 1.1
        onFinished: root.flipAngle = 0
    }

    // --- Geometry (px), shared by the drawing and the grains
    readonly property real hgH: Math.min(height * 0.8, width * 1.2)
    readonly property real hgW: hgH * 0.6
    readonly property real capH: Math.max(6, hgH * 0.05)
    readonly property real bulbL: hgH / 2 - capH - 1
    readonly property real bulbR: hgW / 2 - hgW * 0.07
    readonly property real neck: Math.max(2.2, hgW * 0.028)

    function profile(u) {
        u = Math.max(0, Math.min(1, u));
        const shoulder = 0.8 + 0.2 * Math.sin(Math.min(1, u / 0.28) * Math.PI / 2);
        return neck + (bulbR - neck) * Math.pow(1 - u * u, 1.45) * shoulder;
    }

    // Cumulative volume table, recomputed only when the size changes.
    readonly property var volumes: {
        const N = 200, w = [];
        let total = 0;
        for (let k = 0; k <= N; k++) {
            const r = profile(k / N);
            w.push(r * r);
            total += r * r;
        }
        return {
            N: N,
            w: w,
            total: total
        };
    }

    // Level u holding the fraction `frac`, filling from the neck
    // (fromNeck) or from the rim.
    function level(frac, fromNeck) {
        const t = volumes, target = frac * t.total;
        let acc = 0;
        for (let i = 0; i <= t.N; i++) {
            const k = fromNeck ? t.N - i : i;
            if (acc + t.w[k] >= target) {
                const f = (target - acc) / t.w[k];
                return Math.max(0, Math.min(1, (fromNeck ? k + 1 - f : k + f) / t.N));
            }
            acc += t.w[k];
        }
        return fromNeck ? 0 : 1;
    }

    // Sand levels (recomputed when the sand moves, not every frame)
    readonly property real topU: shownProgress > 0.0005 ? level(shownProgress, true) : 1
    readonly property real bottomU: shownProgress < 0.9995 ? level(1 - shownProgress, false) : 0
    // Levels at quarter-pixel precision: the glass is only repainted when the
    // sand visibly moved (not every second of a long timer).
    readonly property real topPx: Math.round((1 - topU) * bulbL * 4)
    readonly property real bottomPx: Math.round((1 - bottomU) * bulbL * 4)
    readonly property real moundH: Math.min(bulbL * 0.16, (1 - bottomU) * bulbL * 0.9) * Math.min(1, (1 - shownProgress) * 6)
    // Top of the mound, from the neck: length of the falling grains.
    readonly property real fallLength: Math.max(4, (1 - bottomU) * bulbL + moundH * 0.35 - moundH - neck)
    // Freeze in 24 steps: while setting (0.9 s) and melting (0.7 s), the
    // glass is repainted at most 24 times, not every frame.
    readonly property int frostStep: Math.round(frost * 24)
    readonly property bool flowing: shownProgress > 0.0005 && shownProgress < 0.999 && !ringing && flipAngle === 0

    // --- Halos (drawn once, animated through opacity)
    component Halo: Canvas {
        property color tint: "white"
        anchors.centerIn: parent
        width: root.hgH * 1.3
        height: width
        renderTarget: Canvas.FramebufferObject
        onTintChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const r = width / 2;
            const g = ctx.createRadialGradient(r, r, 0, r, r, r);
            g.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, 0.5));
            g.addColorStop(0.45, Qt.rgba(tint.r, tint.g, tint.b, 0.16));
            // Fades out at 85% of the radius: even enlarged, the aura stays inside the
            // panel (DMS clips whatever overflows, which would leave a hard edge).
            g.addColorStop(0.85, Qt.rgba(tint.r, tint.g, tint.b, 0));
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
    }

    // Color halo. The pulses (alarm, frozen aura) are
    // Animators: run by the render thread, with no JavaScript work.
    Item {
        anchors.fill: parent
        opacity: 1 - root.frost

        Halo {
            id: glow
            opacity: 0.4
            tint: root.sandColor

            SequentialAnimation {
                running: root.ringing && root.visible && root.animate
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    glow.opacity = 0.4
                OpacityAnimator {
                    target: glow
                    to: 1
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                OpacityAnimator {
                    target: glow
                    to: 0.3
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // Frozen aura: breathes slowly, even when frozen.
    Item {
        anchors.fill: parent
        opacity: root.frost
        visible: root.frost > 0.005

        Halo {
            id: aura
            tint: root.frostColor
            scale: 1.12
            opacity: 0.85

            SequentialAnimation {
                running: root.frost > 0.5 && root.visible && root.animate
                loops: Animation.Infinite
                OpacityAnimator {
                    target: aura
                    to: 1
                    duration: 2200
                    easing.type: Easing.InOutSine
                }
                OpacityAnimator {
                    target: aura
                    to: 0.7
                    duration: 2200
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // --- Ground shadow: tightens when the hourglass rises
    readonly property real floatY: Math.sin(floatClock * 1.35) * floatAmp
    Canvas {
        id: shadow
        width: root.hgW
        height: root.hgW * 0.2
        x: (root.width - width) / 2
        y: root.height / 2 - 8 + root.hgH / 2 + 16 - height / 2
        scale: 0.9 + 0.08 * (root.floatY + 5) / 10
        opacity: 0.85 - 0.25 * (root.floatY + 5) / 10
        renderTarget: Canvas.FramebufferObject
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            ctx.translate(width / 2, height / 2);
            ctx.scale(1, height / width);
            const g = ctx.createRadialGradient(0, 0, 0, 0, 0, width / 2);
            g.addColorStop(0, Qt.rgba(root.shadowColor.r, root.shadowColor.g, root.shadowColor.b, 0.4));
            g.addColorStop(1, Qt.rgba(root.shadowColor.r, root.shadowColor.g, root.shadowColor.b, 0));
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.arc(0, 0, width / 2, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        }
    }

    // --- The hourglass: floats, tilts, flips (GPU transforms)
    Item {
        id: body
        width: root.hgW
        height: root.hgH
        x: (root.width - width) / 2
        y: root.height / 2 - 8 - height / 2 + root.floatY
        rotation: root.flipAngle + Math.sin(root.floatClock * 0.85) * 1.6 * root.floatAmp / 5

        Canvas {
            id: glass
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            // Repaint only when the look changes.
            Connections {
                target: root
                function onTopPxChanged() {
                    glass.requestPaint();
                }
                function onBottomPxChanged() {
                    glass.requestPaint();
                }
                function onSandColorChanged() {
                    glass.requestPaint();
                }
                function onFrostStepChanged() {
                    glass.requestPaint();
                }
                function onFlowingChanged() {
                    glass.requestPaint();
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function rgba(c, a) {
                return Qt.rgba(c.r, c.g, c.b, a);
            }
            function mix(c1, c2, t) {
                return Qt.rgba(c1.r + (c2.r - c1.r) * t, c1.g + (c2.g - c1.g) * t, c1.b + (c2.b - c1.b) * t, 1);
            }

            function outline(ctx) {
                const L = root.bulbL, S = 40;
                ctx.beginPath();
                for (let i = 0; i <= S; i++)
                    ctx.lineTo(-root.profile(i / S), -(1 - i / S) * L);
                for (let i = S; i >= 0; i--)
                    ctx.lineTo(-root.profile(i / S), (1 - i / S) * L);
                for (let i = 0; i <= S; i++)
                    ctx.lineTo(root.profile(i / S), (1 - i / S) * L);
                for (let i = S; i >= 0; i--)
                    ctx.lineTo(root.profile(i / S), -(1 - i / S) * L);
                ctx.closePath();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const L = root.bulbL, R = root.bulbR, n = root.neck, capH = root.capH;
                const frost = root.frost;
                const sand = mix(root.sandColor, root.frostColor, frost * 0.55);
                const sandLight = mix(sand, Qt.rgba(1, 1, 1, 1), 0.28);
                const sandDark = mix(sand, Qt.rgba(0, 0, 0, 1), 0.22);
                ctx.translate(width / 2, height / 2);

                // Glass
                outline(ctx);
                let g = ctx.createLinearGradient(-R, 0, R, 0);
                g.addColorStop(0, rgba(root.glassColor, 0.07 + 0.06 * frost));
                g.addColorStop(0.5, rgba(root.glassColor, 0.025 + 0.04 * frost));
                g.addColorStop(1, rgba(root.glassColor, 0.06 + 0.06 * frost));
                ctx.fillStyle = g;
                ctx.fill();

                ctx.save();
                outline(ctx);
                ctx.clip();

                // Top sand, with a dip in the middle while it flows (or frozen).
                if (root.shownProgress > 0.0005) {
                    const u = root.topU, yS = -(1 - u) * L;
                    const dip = root.shownProgress < 0.995 && !root.ringing ? Math.min(L * 0.1, (1 - u) * L * 0.5) : 0;
                    const dw = root.profile(u) * 0.55;
                    ctx.beginPath();
                    ctx.moveTo(-R - 2, n);
                    ctx.lineTo(-R - 2, yS);
                    ctx.lineTo(-dw, yS);
                    ctx.quadraticCurveTo(0, yS + dip * 2, dw, yS);
                    ctx.lineTo(R + 2, yS);
                    ctx.lineTo(R + 2, n);
                    ctx.closePath();
                    g = ctx.createLinearGradient(0, yS, 0, 0);
                    g.addColorStop(0, sandLight);
                    g.addColorStop(1, sandDark);
                    ctx.fillStyle = g;
                    ctx.fill();
                }

                // Bottom sand: mound
                if (root.shownProgress < 0.9995) {
                    const u = root.bottomU, rB = root.profile(u), m = root.moundH;
                    const flat = (1 - u) * L + m * 0.35;
                    ctx.beginPath();
                    ctx.moveTo(-R - 2, L + 2);
                    for (let i = 0; i <= 28; i++) {
                        const x = -R - 2 + (2 * R + 4) * i / 28;
                        ctx.lineTo(x, flat - m * Math.exp(-Math.pow(x / (rB * 0.62), 2)));
                    }
                    ctx.lineTo(R + 2, L + 2);
                    ctx.closePath();
                    g = ctx.createLinearGradient(0, flat - m, 0, L);
                    g.addColorStop(0, sandLight);
                    g.addColorStop(1, sandDark);
                    ctx.fillStyle = g;
                    ctx.fill();
                }

                // Frost inside the glass: cold veil + crystals on the walls
                if (frost > 0.01) {
                    ctx.fillStyle = rgba(root.frostColor, 0.2 * frost);
                    ctx.fillRect(-R - 4, -L - 4, 2 * R + 8, 2 * L + 8);
                    ctx.strokeStyle = rgba(root.frostColor, 0.7 * frost);
                    ctx.lineWidth = 0.8;
                    for (let i = 0; i < 14; i++) {
                        const s = Math.sin(i * 12.9898) * 43758.5453, h = s - Math.floor(s);
                        const s2 = Math.sin(i * 78.233) * 12543.1, h2 = s2 - Math.floor(s2);
                        const y = (h * 2 - 1) * L * 0.92;
                        const side = i % 2 ? 1 : -1;
                        const x = side * root.profile(1 - Math.abs(y) / L) * 0.94;
                        const size = (3 + h2 * 5) * frost;
                        for (let a = 0; a < 6; a++) {
                            const ang = a * Math.PI / 3 + h2;
                            ctx.beginPath();
                            ctx.moveTo(x, y);
                            ctx.lineTo(x + Math.cos(ang) * size, y + Math.sin(ang) * size);
                            ctx.stroke();
                        }
                    }
                }
                ctx.restore();

                // Outline + highlights
                outline(ctx);
                ctx.lineWidth = 1.4;
                ctx.strokeStyle = rgba(mix(root.glassColor, root.frostColor, frost), 0.3 + 0.35 * frost);
                ctx.stroke();

                ctx.lineCap = "round";
                ctx.lineWidth = Math.max(1.6, root.hgW * 0.022);
                for (let s = -1; s <= 1; s += 2) {
                    ctx.strokeStyle = rgba(root.glassColor, s < 0 ? 0.32 : 0.18);
                    ctx.beginPath();
                    for (let i = 0; i <= 12; i++) {
                        const u = s < 0 ? 0.14 + 0.4 * i / 12 : 0.12 + 0.3 * i / 12;
                        ctx.lineTo(-root.profile(u) * 0.74, s * (1 - u) * L);
                    }
                    ctx.stroke();
                }

                // Bases, with an accent rim on the glass side
                const capW = root.hgW;
                for (let s = -1; s <= 1; s += 2) {
                    const y = s < 0 ? -L - capH : L;
                    g = ctx.createLinearGradient(0, y, 0, y + capH);
                    g.addColorStop(0, mix(mix(root.capColor, Qt.rgba(1, 1, 1, 1), 0.12), root.frostColor, frost * 0.3));
                    g.addColorStop(1, mix(root.capColor, root.frostColor, frost * 0.2));
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.roundedRect(-capW / 2, y, capW, capH, capH / 2, capH / 2);
                    ctx.fill();
                    ctx.fillStyle = rgba(sand, 0.75);
                    ctx.fillRect(-capW / 2 + capH, s < 0 ? y + capH - 1.5 : y, capW - capH * 2, 1.5);

                    // Frost settling on the base: an uneven deposit, like
                    // rime on a ledge.
                    if (frost > 0.01) {
                        const edgeY = s < 0 ? y : y + capH;
                        ctx.fillStyle = rgba(root.frostColor, 0.85 * frost);
                        for (let i = 0; i < 22; i++) {
                            const hh = Math.abs(Math.sin((i + s * 7) * 43.13) * 9127.3) % 1;
                            const bx = -capW / 2 + capH * 0.4 + (capW - capH * 0.8) * (i + 0.5) / 22;
                            const br = (1 + hh * 2.2) * frost;
                            ctx.beginPath();
                            ctx.ellipse(bx - br, edgeY - br * 0.7, br * 2, br * 1.4);
                            ctx.fill();
                        }
                    }
                }
            }
        }

        // --- Stream of grains: computed positions, no repaint.
        //     Frozen, the clock stops: the grains stay suspended.
        Rectangle {
            visible: root.flowing
            x: (parent.width - width) / 2
            y: parent.height / 2 + root.neck
            width: Math.max(1, root.neck * 0.45)
            height: root.fallLength
            radius: width / 2
            color: root.sandColor
            opacity: 0.3 * (1 - root.frost * 0.5)
        }

        Repeater {
            model: root.flowing ? 11 : 0

            Rectangle {
                required property int index
                readonly property real phase: root.clock * 1.7 + index / 11
                readonly property real q: phase - Math.floor(phase)
                readonly property real seed: Math.sin((index + Math.floor(phase) * 13) * 127.1) * 43758.5453
                readonly property real jitter: seed - Math.floor(seed)
                width: Math.max(1.8, root.hgW * 0.022) * (0.8 + 0.4 * jitter)
                height: width
                radius: width / 2
                x: body.width / 2 - width / 2 + (jitter - 0.5) * root.neck * 0.9
                y: body.height / 2 + root.neck + Math.pow(q, 1.5) * root.fallLength - height / 2
                color: Qt.tint(Qt.lighter(root.sandColor, 1.25), Qt.rgba(root.frostColor.r, root.frostColor.g, root.frostColor.b, root.frost * 0.6))
            }
        }
    }
}
