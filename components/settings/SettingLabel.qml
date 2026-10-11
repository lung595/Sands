import QtQuick
import qs.Common
import qs.Widgets

// Title and description of a setting row. Both take the width they are given and wrap
// there, never elide: that is what keeps a narrow page readable.
Column {
    id: root

    required property string title
    property string description: ""
    // Battery level and cost note of a costly setting; empty level = no chip
    property string level: ""
    property string cost: ""

    spacing: Theme.spacingXS

    StyledText {
        width: parent.width
        text: root.title
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    StyledText {
        width: parent.width
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        visible: root.description !== ""
    }

    BatteryPill {
        visible: root.level !== ""
        level: root.level || "light"
    }

    StyledText {
        width: parent.width
        text: root.cost
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        visible: root.level !== "" && root.cost !== ""
    }
}
