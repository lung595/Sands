import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

// One-line text field. Text that does not fit is cut at the edge and scrolls
// with the cursor (never a second line, never an ellipsis); a refusal turns
// the border to the error colour. The accessible name and the tooltip carry
// the whole text.
Rectangle {
    id: root
    objectName: "control"

    property alias text: input.text
    property string placeholder: ""
    property string accessibleName: ""
    property int maxLength: 200
    property bool invalid: false

    signal accepted
    signal edited

    function clear() {
        input.text = "";
    }

    // Shows the start of the text again (the end stays reachable with the cursor)
    function showStart() {
        input.cursorPosition = 0;
    }

    implicitHeight: 44
    radius: Theme.cornerRadius
    color: "transparent"
    border.width: root.invalid || input.activeFocus ? 2 : 1
    border.color: root.invalid ? Theme.error : (input.activeFocus ? Theme.primary : Theme.outline)

    Accessible.role: Accessible.EditableText
    Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.placeholder

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
        maximumLength: root.maxLength
        selectByMouse: true
        // Loaded text and a lost focus show the start: the program name, not its tail
        Component.onCompleted: root.showStart()
        onTextChanged: if (!activeFocus)
            root.showStart()
        onActiveFocusChanged: if (!activeFocus)
            root.showStart()
        onAccepted: root.accepted()
        onTextEdited: root.edited()
    }

    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text === "" && !input.activeFocus
        text: root.placeholder
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
    }
    ToolTip.visible: hover.hovered && input.text !== ""
    ToolTip.delay: 600
    ToolTip.text: input.text
}
