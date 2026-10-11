import QtQuick
import qs.Common
import qs.Widgets

// The three-level battery-use chip of a costly setting. Colours come from the
// theme and carry meaning (error, warning, success), never decoration; the text
// is always there so colour is not the only signal.
Rectangle {
    id: root

    // "high" | "some" | "light" (see Sections.LEVELS)
    required property string level

    readonly property color tone: level === "high" ? Theme.error : (level === "some" ? Theme.warning : Theme.success)
    readonly property string text: level === "high" ? "High battery use" : (level === "some" ? "Some battery use" : "Light on battery")

    implicitWidth: label.implicitWidth + Theme.spacingS * 2
    implicitHeight: label.implicitHeight + Theme.spacingXS
    radius: height / 2
    color: Qt.rgba(tone.r, tone.g, tone.b, 0.16)

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.fontSizeSmall
        color: root.tone
    }
}
