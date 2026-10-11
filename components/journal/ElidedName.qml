import QtQuick
import qs.Common
import qs.Widgets

// A timer name on one line, cut with an ellipsis; the full name shows in a
// tooltip only when it was cut.
StyledText {
    id: root

    wrapMode: Text.NoWrap
    elide: Text.ElideRight
    font.pixelSize: Theme.fontSizeMedium
    color: Theme.surfaceText

    HoverHandler {
        id: hover
    }

    DankTooltipV2 {
        id: tip
    }

    Timer {
        interval: 600
        running: hover.hovered && root.truncated
        onTriggered: tip.show(root.text, root, 0, 0, "bottom")
    }

    Connections {
        target: hover
        function onHoveredChanged() {
            if (!hover.hovered)
                tip.hide();
        }
    }
}
