import QtQuick
import qs.Common
import qs.Widgets
import "SettingHost.js" as SettingHost

// A setting picked from a few cards. Cards wrap onto the next line below 152 px
// each, so nothing is drawn over its neighbour on a narrow page. Arrow keys move
// inside the group; a disabled card shows its reason and cannot be picked.
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    // [{label, value, help, enabled?, reason?}]
    required property var options
    property string defaultValue: ""
    property string value: defaultValue
    // The card shown as picked: the saved value unless the caller knows better
    // (a saved style without a scene is drawn as the default one)
    property string shown: value
    // Set once the saved value is read, so the read itself is never written back
    property bool ready: false

    readonly property int cardMin: 152
    readonly property int perRow: Math.max(1, Math.min(options.length, Math.floor((width + Theme.spacingS) / (cardMin + Theme.spacingS))))

    width: parent.width
    spacing: Theme.spacingS

    Component.onCompleted: Qt.callLater(() => SettingHost.load(root))
    onValueChanged: SettingHost.save(root)

    function _step(delta) {
        const n = options.length;
        for (let i = 1; i <= n; i++) {
            const o = options[(options.findIndex(x => x.value === shown) + delta * i + n * n) % n];
            if (o.enabled !== false) {
                value = o.value;
                return;
            }
        }
    }

    SettingLabel {
        width: parent.width
        title: root.label
        description: root.description
    }

    Flow {
        id: cards
        width: parent.width
        spacing: Theme.spacingS
        activeFocusOnTab: true
        Keys.onLeftPressed: root._step(-1)
        Keys.onUpPressed: root._step(-1)
        Keys.onRightPressed: root._step(1)
        Keys.onDownPressed: root._step(1)

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: card
                required property var modelData
                objectName: "card-" + modelData.value
                readonly property bool selected: root.shown === modelData.value
                readonly property bool usable: modelData.enabled !== false

                width: Math.floor((cards.width - (root.perRow - 1) * cards.spacing) / root.perRow)
                height: texts.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: mouse.pressed && usable ? Theme.surfaceContainerHighest : mouse.containsMouse && usable ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                border.width: selected ? (cards.activeFocus ? 3 : 2) : 1
                border.color: selected ? Theme.primary : Theme.outline
                opacity: usable ? 1 : 0.38

                Column {
                    id: texts
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        text: card.modelData.label
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }
                    StyledText {
                        width: parent.width
                        text: card.usable ? card.modelData.help : (card.modelData.reason ?? "")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: card.usable
                    onClicked: {
                        cards.forceActiveFocus();
                        root.value = card.modelData.value;
                    }
                }
            }
        }
    }
}
