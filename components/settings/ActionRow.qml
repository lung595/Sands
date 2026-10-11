import QtQuick
import qs.Common
import qs.Widgets
import "../daemon/PlainText.js" as PlainText

// One end action: its name and what it does, for a command of the user's own
// the name and command fields, then the launcher words as chips and a field to
// add one. Every refusal text comes from the section (ActionRows.js); this
// file only draws and reports what was typed. Each part takes the width it is
// given and wraps there, so a narrow page never draws one over another.
Column {
    id: root

    // One entry of ActionRows.rows()
    required property var row
    // Reason shown under the word field / the command fields, set by the section
    property string wordError: ""
    property string commandError: ""
    // "name" or "command": the field to mark when commandError is set
    property string commandField: ""
    property string guideUrl: ""

    signal wordAdded(string word)
    // The user typed again: the section clears the reason
    signal wordTyped
    signal wordRemoved(string word)
    signal commandChanged(string name, string line)
    // The user typed again: the section clears the reason
    signal commandTyped
    signal removed

    width: parent.width
    spacing: Theme.spacingS

    Row {
        width: parent.width
        spacing: Theme.spacingS

        // A Row ignores anchors: the icon sits in an item as tall as the title line
        Item {
            id: glyph
            width: 16
            height: 24

            DankIcon {
                anchors.centerIn: parent
                name: root.row.icon
                size: 16
                color: Theme.surfaceVariantText
            }
        }
        SettingLabel {
            width: parent.width - glyph.width - Theme.spacingS
            title: PlainText.plain(root.row.name)
            description: root.row.description
        }
    }

    // Own commands only: a name, then the whole command on its own line
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: !root.row.builtin

        TextBox {
            id: nameBox
            width: parent.width
            text: root.row.name
            placeholder: "Name"
            accessibleName: "Name of the command"
            maxLength: 40
            invalid: root.commandError !== "" && root.commandField === "name"
            onAccepted: root.commandChanged(nameBox.text, commandBox.text)
            onEdited: root.commandTyped()
        }
        TextBox {
            id: commandBox
            width: parent.width
            text: root.row.command
            placeholder: "Program and arguments"
            accessibleName: "Command: " + root.row.command
            maxLength: 600
            invalid: root.commandError !== "" && root.commandField === "command"
            onAccepted: root.commandChanged(nameBox.text, commandBox.text)
            onEdited: root.commandTyped()
        }
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.row.words

            // The visible chip is small (12/16); the item around it is the 44 px target
            delegate: Item {
                id: chip
                required property string modelData
                objectName: "control"
                width: Math.min(label.implicitWidth + 44 + Theme.spacingS, root.width)
                height: 44
                Accessible.role: Accessible.Button
                Accessible.name: "Remove the word " + modelData

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: (parent.height - Math.max(24, label.implicitHeight + Theme.spacingS)) / 2
                    anchors.bottomMargin: anchors.topMargin
                    radius: 8
                    color: Theme.surfaceContainerHigh
                }
                StyledText {
                    id: label
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: close.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
                DankIcon {
                    id: close
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    name: "close"
                    size: 16
                    color: Theme.surfaceVariantText
                }
                TapHandler {
                    onTapped: root.wordRemoved(chip.modelData)
                }
            }
        }
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        TextBox {
            id: wordBox
            width: Math.min(120, root.width)
            placeholder: "Add a word"
            accessibleName: "Add a word to " + root.row.name
            maxLength: 24
            invalid: root.wordError !== ""
            onAccepted: {
                root.wordAdded(wordBox.text);
                // The section clears the error and keeps the text when the word is refused
                if (root.wordError === "")
                    wordBox.clear();
            }
            onEdited: {
                wordBox.text = wordBox.text.replace(/\s+/g, "").toLowerCase();
                root.wordTyped();
            }
        }
        OutlineButton {
            visible: !root.row.builtin
            text: "Remove"
            iconName: "delete"
            onClicked: root.removed()
        }
    }

    FieldError {
        text: root.wordError !== "" ? root.wordError : root.commandError
        url: root.guideUrl
    }
}
