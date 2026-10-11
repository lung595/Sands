import QtQuick
import qs.Common
import qs.Widgets
import "Sections.js" as Sections
import "Search.js" as Search

// The settings page: search on top, the section rail on the left, one section
// at a time on the right. Only the open section is built (Loader), so a closed
// page costs nothing. Picking a search result opens its section and fades a
// highlight over its row once.
Item {
    id: root
    objectName: "settingsPage"

    required property var soundOptions
    required property var daemon

    property string section: Sections.visibleSections()[0].id
    property string query: ""
    readonly property var results: Search.find(query, prepared)
    readonly property var prepared: Search.prepare()
    // Below this width the rail would crush the section, so it sits on top
    readonly property bool narrow: width < 400
    property string pendingKey: ""

    width: parent ? parent.width : 400
    implicitHeight: body.implicitHeight

    function open(id, key) {
        query = "";
        section = id;
        pendingKey = key || "";
        if (pendingKey !== "")
            flashTimer.restart();
    }

    function findRow(item, key) {
        for (const c of item.children) {
            if (c.settingKey === key)
                return c;
            const hit = findRow(c, key);
            if (hit)
                return hit;
        }
        return null;
    }

    // Waits one tick so the Loader has built the section before the row is looked up
    Timer {
        id: flashTimer
        interval: 0
        onTriggered: {
            const row = root.findRow(content, root.pendingKey);
            if (!row)
                return;
            const p = row.mapToItem(content, 0, 0);
            flash.x = p.x;
            flash.y = p.y;
            flash.width = row.width;
            flash.height = row.height;
            fade.restart();
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: Theme.spacingM

        Rectangle {
            width: parent.width
            height: 44
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            objectName: "control"
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? Theme.primary : Theme.outline

            DankIcon {
                id: lens
                name: "search"
                size: 20
                color: Theme.surfaceVariantText
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: field
                anchors.left: lens.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                maximumLength: Search.MAX_QUERY
                text: root.query
                onTextChanged: root.query = text
                Keys.onEscapePressed: root.query = ""
                Keys.onReturnPressed: {
                    if (root.results.length > 0)
                        root.open(root.results[0].section, root.results[0].key);
                }
            }

            StyledText {
                anchors.left: field.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Search settings"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
                visible: field.text === "" && !field.activeFocus
            }
        }

        // Ctrl+F or / from anywhere on the page
        Shortcut {
            sequences: ["Ctrl+F", "/"]
            enabled: !field.activeFocus
            onActivated: field.forceActiveFocus()
        }

        StyledText {
            width: parent.width
            visible: root.query !== "" && root.results.length === 0
            text: "No setting found"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }

        Column {
            width: parent.width
            visible: root.query !== "" && root.results.length > 0
            spacing: 4

            Repeater {
                model: root.results

                delegate: Rectangle {
                    id: hit
                    required property var modelData
                    readonly property var setting: Sections.SETTINGS.find(s => s.key === modelData.key)
                    width: parent.width
                    height: 44
                    radius: Theme.cornerRadius
                    color: tap.pressed || hov.hovered ? Theme.surfaceContainerHigh : "transparent"
                    objectName: "control"

                    HoverHandler {
                        id: hov
                    }
                    TapHandler {
                        id: tap
                        onTapped: root.open(hit.modelData.section, hit.modelData.key)
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: hit.setting.label
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Flow {
            id: layout
            width: parent.width
            visible: root.query === ""
            spacing: Theme.spacingM

            SectionRail {
                id: rail
                width: root.narrow ? layout.width : 176
                sections: Sections.visibleSections()
                current: root.section
                onPicked: id => root.open(id, "")
            }

            Item {
                id: content
                width: root.narrow ? layout.width : layout.width - 176 - Theme.spacingM
                height: loader.item ? loader.item.implicitHeight : 0

                Loader {
                    id: loader
                    width: parent.width
                    sourceComponent: ({
                            "timers": timers,
                            "appearance": appearance,
                            "alerts": alerts,
                            "help": help
                        })[root.section]
                }

                // One-shot highlight of a found row: it fades out and stops
                Rectangle {
                    id: flash
                    radius: Theme.cornerRadius
                    color: Theme.primary
                    opacity: 0
                }

                SequentialAnimation {
                    id: fade
                    PropertyAction {
                        target: flash
                        property: "opacity"
                        value: 0.25
                    }
                    NumberAnimation {
                        target: flash
                        property: "opacity"
                        to: 0
                        duration: SettingsData.reduceMotion ? 150 : 600
                    }
                }
            }
        }
    }

    Component {
        id: timers
        TimersSection {}
    }
    Component {
        id: appearance
        AppearanceSection {}
    }
    Component {
        id: help
        HelpSection {}
    }
    Component {
        id: alerts
        AlertsSection {
            soundOptions: root.soundOptions
            daemon: root.daemon
        }
    }
}
