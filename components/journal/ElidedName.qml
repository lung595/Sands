import QtQuick
import qs.Common
import qs.Widgets

// A timer name on one line, cut with an ellipsis; the full name shows in a
// tooltip only when it was cut.
StyledText {
    id: root

    textFormat: Text.PlainText
    wrapMode: Text.NoWrap
    elide: Text.ElideRight
    font.pixelSize: Theme.fontSizeMedium
    color: Theme.surfaceText

    HoverHandler {
        id: hover
    }

    // Built only while a cut name is under the pointer
    Loader {
        active: hover.hovered && root.truncated
        sourceComponent: Item {
            DankTooltipV2 {
                id: tip
            }
            Timer {
                interval: 600
                running: true
                onTriggered: tip.show(root.text, root, 0, 0, "bottom")
            }
            Component.onDestruction: tip.hide()
        }
    }
}
