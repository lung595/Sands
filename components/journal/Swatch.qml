import QtQuick
import qs.Common
import "Texture.js" as Texture

// The 16 px legend square of one layer, with the same texture as the layer.
Canvas {
    id: root

    required property int kind
    // Only listed so that a theme change triggers a repaint
    readonly property var colours: [Theme.primary, Theme.surface]

    width: 16
    height: 16
    onColoursChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        // Rounded corners of 4
        ctx.beginPath();
        ctx.roundedRect(0, 0, 16, 16, 4, 4);
        ctx.clip();
        Texture.paint(ctx, kind, 0, 0, 16, 16, Theme.primary.toString(), Theme.surface.toString());
    }
}
