import QtQuick
import qs.Common
import qs.Widgets
import "ActionRows.js" as ActionRows

// The end actions: one row per action with its launcher words, the user's own
// commands, and a way to add one. The two stored values live in ObjectStores;
// every edit goes through ActionRows.js and is saved only when it is accepted.
Column {
    id: root

    required property var daemon
    readonly property string settingKey: "endActions"
    readonly property string guideUrl: (daemon ? daemon.guideUrl : "") + "#" + ActionRows.GUIDE_ANCHOR
    readonly property var rows: ActionRows.rows(personal.value, words.value)
    // Reason per row id: { id: { word, command, field } }
    property var errors: ({})
    // The command being typed before it is valid
    property bool drafting: false
    property string draftError: ""
    property string draftField: ""

    width: parent.width
    spacing: Theme.spacingM

    ObjectStore {
        id: personal
        settingKey: ActionRows.KEY_PERSONAL
        defaultValue: []
    }
    ObjectStore {
        id: words
        settingKey: ActionRows.KEY_WORDS
        defaultValue: ({})
    }

    function setError(id, patch) {
        const next = Object.assign({}, errors);
        next[id] = Object.assign({}, errors[id] || {}, patch);
        errors = next;
    }

    function saveWords(res, id) {
        if (!res.ok) {
            setError(id, {
                "word": res.text
            });
            return false;
        }
        setError(id, {
            "word": ""
        });
        words.value = res.overrides;
        return true;
    }

    StyledText {
        width: parent.width
        text: "End actions · Type one of an action's words after a timer, for example “45m film off”. Any word works, even a made-up one."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Repeater {
        // A count, not the rows: saving a word replaces `rows`, and a list model
        // would rebuild every delegate and drop the focus and the unsaved text
        model: root.rows.length

        delegate: ActionRow {
            id: item
            required property int index
            // Briefly undefined while the last delegates go after a removal
            readonly property var shown: root.rows[index] ?? root.rows[0]
            readonly property var modelData: shown
            row: shown
            guideUrl: root.guideUrl
            wordError: (root.errors[modelData.id] || {}).word || ""
            commandError: (root.errors[modelData.id] || {}).command || ""
            commandField: (root.errors[modelData.id] || {}).field || ""
            onWordTyped: root.setError(modelData.id, {
                "word": ""
            })
            onWordAdded: word => root.saveWords(ActionRows.addWord(personal.value, words.value, modelData.id, word), modelData.id)
            onWordRemoved: word => root.saveWords(ActionRows.removeWord(personal.value, words.value, modelData.id, word), modelData.id)
            onCommandTyped: root.setError(modelData.id, {
                "command": ""
            })
            onCommandChanged: (name, line) => {
                const res = ActionRows.setCommand(personal.value, modelData.index, name, line);
                if (res.ok) {
                    root.setError(modelData.id, {
                        "command": ""
                    });
                    personal.value = res.personal;
                } else {
                    root.setError(modelData.id, {
                        "command": res.text,
                        "field": res.field
                    });
                }
            }
            onRemoved: {
                const res = ActionRows.removeCommand(personal.value, words.value, modelData.index);
                root.errors = ({});
                words.value = res.overrides;
                personal.value = res.personal;
            }
        }
    }

    StyledText {
        width: parent.width
        visible: !root.rows.some(r => !r.builtin)
        text: ActionRows.EMPTY_NOTE
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Column {
        id: draft
        width: parent.width
        spacing: Theme.spacingS
        visible: root.drafting

        TextBox {
            id: draftName
            width: parent.width
            placeholder: "Name"
            accessibleName: "Name of the new command"
            maxLength: 40
            invalid: root.draftError !== "" && root.draftField === "name"
            onEdited: root.draftError = ""
        }
        TextBox {
            id: draftCommand
            width: parent.width
            placeholder: "Program and arguments"
            accessibleName: "Command of the new command"
            maxLength: 600
            invalid: root.draftError !== "" && root.draftField === "command"
            onEdited: root.draftError = ""
            onAccepted: root.commitDraft()
        }
        FieldError {
            text: root.draftError
            url: root.guideUrl
        }
        Flow {
            width: parent.width
            spacing: Theme.spacingS
            OutlineButton {
                text: "Add"
                iconName: "check"
                onClicked: root.commitDraft()
            }
            OutlineButton {
                text: "Cancel"
                iconName: "close"
                onClicked: root.closeDraft()
            }
        }
    }

    function commitDraft() {
        const res = ActionRows.addCommand(personal.value, draftName.text, draftCommand.text);
        if (!res.ok) {
            draftError = res.text;
            draftField = res.field;
            return;
        }
        personal.value = res.personal;
        closeDraft();
    }

    function closeDraft() {
        drafting = false;
        draftError = "";
        draftName.clear();
        draftCommand.clear();
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        OutlineButton {
            visible: !root.drafting
            text: "Add a command"
            iconName: "add"
            onClicked: root.drafting = true
        }
        OutlineButton {
            text: "Reset the words"
            iconName: "restart_alt"
            enabled: ActionRows.wordsChanged(words.value)
            opacity: enabled ? 1 : 0.4
            onClicked: {
                root.errors = ({});
                words.value = ActionRows.resetWords();
            }
        }
    }
}
