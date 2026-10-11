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

    // Ctrl+F focuses the search from anywhere on the page while it is shown; "/" does
    // too unless a text field has the focus (it would type the character). Shortcuts,
    // because no item of the page holds the focus until the field does.
    // cursorPosition exists on TextInput, TextField and TextEdit, so it tells a text field apart without importing Controls.
    readonly property bool typing: !!Window.activeFocusItem && Window.activeFocusItem.cursorPosition !== undefined

    function focusSearch() {
        field.forceActiveFocus();
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.visible
        onActivated: root.focusSearch()
    }

    Shortcut {
        sequence: "/"
        enabled: root.visible && !root.typing
        onActivated: root.focusSearch()
    }

    // Esc only clears a query; with nothing to clear it reaches the window
    function clearQuery() {
        const had = query !== "";
        query = "";
        return had;
    }

    // Enter opens the best hit
    function openFirst() {
        if (results.length > 0)
            open(results[0].section, results[0].key);
    }

    function open(id, key) {
        query = "";
        section = id;
        pendingKey = key || "";
        if (pendingKey !== "")
            flashTimer.restart();
    }

    // The shown row carrying this key; a hidden row (zero height) does not count
    function findRow(item, key) {
        for (const c of item.children) {
            if (c.settingKey === key && c.visible && c.height > 0)
                return c;
            const hit = findRow(c, key);
            if (hit)
                return hit;
        }
        return null;
    }

    // What the highlight lands on: the row itself, or the row it depends on when it is
    // hidden by the current state (the prefix hides behind the automatic detection)
    function flashTarget(key) {
        const entry = Sections.SETTINGS.find(s => s.key === key);
        return findRow(content, key) || (entry && entry.anchor ? findRow(content, entry.anchor) : null);
    }

    // Brings the row into the settings flickable when the page sits inside one (DMS PluginsTab scrolls its pluginFlickable)
    function reveal(row) {
        let f = root.parent;
        while (f && f.contentY === undefined)
            f = f.parent;
        if (!f)
            return;
        const y = row.mapToItem(f.contentItem, 0, 0).y;
        if (y < f.contentY || y + row.height > f.contentY + f.height)
            f.contentY = Math.max(0, y - Theme.spacingL);
    }

    readonly property int fadeDuration: SettingsData.reduceMotion ? 150 : 600

    // Waits one tick so the Loader has built the section before the row is looked up
    Timer {
        id: flashTimer
        interval: 0
        onTriggered: {
            const row = root.flashTarget(root.pendingKey);
            if (!row)
                return;
            const p = row.mapToItem(content, 0, 0);
            flash.x = p.x;
            flash.y = p.y;
            flash.width = row.width;
            flash.height = row.height;
            root.reveal(row);
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
                objectName: "searchField"
                anchors.left: lens.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                maximumLength: Search.MAX_QUERY
                onTextChanged: root.query = text
                // Typing breaks a text binding, so the page pushes its own clears back
                Connections {
                    function onQueryChanged() {
                        if (field.text !== root.query)
                            field.text = root.query;
                    }
                    target: root
                }
                Keys.onEscapePressed: event => event.accepted = root.clearQuery()
                Keys.onReturnPressed: root.openFirst()
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

        StyledText {
            width: parent.width
            leftPadding: Theme.spacingM
            visible: root.query !== "" && root.results.length === 0
            text: "No setting found. Try another word."
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
                    required property int index
                    readonly property var setting: Sections.SETTINGS.find(s => s.key === modelData.key)
                    width: parent.width
                    height: 44
                    radius: Theme.cornerRadius
                    // The first hit is the one Enter opens, so it reads as selected
                    color: tap.pressed || hov.hovered || index === 0 ? Theme.surfaceContainerHigh : "transparent"
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
                    objectName: "flash"
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
                        duration: root.fadeDuration
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
