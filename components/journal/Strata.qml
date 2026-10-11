import QtQuick
import qs.Common
import "Journal.js" as Journal
import "Texture.js" as Texture

// "Strata": the week as one glass, one layer of sand per name, stacked from
// the bottom; the legend below reads each name and time. The layers rise once
// when the view opens (a brief transition, a repaint of this small canvas
// only), then nothing moves.
Column {
    id: root

    // [{ name, ms, folded }], longest first, already folded to five
    required property var shown
    required property bool reducedMotion

    // One rise: 200 ms per layer, each starting 30 ms after the previous
    readonly property int riseMs: 200
    readonly property int stepMs: 30
    // Time since the opening, in ms; past the end every layer is in place
    property real elapsed: reducedMotion ? 1e6 : 0
    readonly property var heights: Journal.layerHeights(shown)

    spacing: Theme.spacingS

    NumberAnimation on elapsed {
        running: !root.reducedMotion && root.shown.length > 0
        from: 0
        to: root.riseMs + root.stepMs * root.shown.length
        duration: root.riseMs + root.stepMs * root.shown.length
    }

    Canvas {
        id: glass

        // Only listed so that a theme change triggers a repaint
        readonly property var colours: [Theme.primary, Theme.surfaceContainer, Theme.outline]

        anchors.horizontalCenter: parent.horizontalCenter
        width: 208
        height: 200
        onColoursChanged: requestPaint()
        Connections {
            target: root
            function onElapsedChanged() {
                glass.requestPaint();
            }
            function onShownChanged() {
                glass.requestPaint();
            }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            // The glass's own units: viewBox 118 128 104 100, drawn at 2x
            ctx.scale(2, 2);
            ctx.translate(-118, -128);
            const bulb = () => {
                ctx.beginPath();
                ctx.moveTo(124, 220);
                ctx.lineTo(216, 220);
                ctx.bezierCurveTo(216, 172, 175, 150, 175, 130);
                ctx.lineTo(165, 130);
                ctx.bezierCurveTo(165, 150, 124, 172, 124, 220);
                ctx.closePath();
            };
            ctx.save();
            bulb();
            ctx.clip();
            let y = 220;
            for (let i = 0; i < root.heights.length; i++) {
                y -= root.heights[i];
                const p = Math.max(0, Math.min(1, (root.elapsed - root.stepMs * i) / root.riseMs));
                // Cubic ease out (kit curve): the layer slows as it settles
                const rise = 100 * Math.pow(1 - p, 3);
                Texture.paint(ctx, Journal.textureOf(i), 122, y + rise, 96, root.heights[i] - 1, Theme.primary.toString(), Theme.surfaceContainer.toString());
            }
            ctx.restore();
            bulb();
            ctx.strokeStyle = Theme.outline.toString();
            ctx.lineWidth = 1.5;
            ctx.stroke();
            ctx.fillStyle = Theme.outline.toString();
            ctx.beginPath();
            ctx.roundedRect(118, 220, 104, 6, 3, 3);
            ctx.fill();
        }
    }

    Repeater {
        model: root.shown
        delegate: Row {
            required property var modelData
            required property int index

            width: root.width
            spacing: Theme.spacingS

            Swatch {
                anchors.verticalCenter: parent.verticalCenter
                kind: Journal.textureOf(index)
            }

            ElidedName {
                width: parent.width - 16 - timeText.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
            }

            StyledTime {
                id: timeText
                anchors.verticalCenter: parent.verticalCenter
                text: Journal.duration(modelData.ms)
            }
        }
    }
}
