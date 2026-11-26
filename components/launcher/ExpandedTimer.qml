pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import ".."
import "Card.js" as Card

// The open card of the Timers row (variant A): a large running hourglass,
// the name (click or F2 renames it), the big time, a line of icons (end,
// duration, notice, sound), then −1/+1/+5 and the round buttons. A ringing
// timer offers Stop, the snooze choices and Restart instead. The other
// timers follow as mini-cards. Shows what it is given and calls the daemon;
// SectionCard decides when it is open.
Item {
    id: root

    required property var daemon
    required property var timer
    required property var words
    property bool use24h: true
    property bool animate: false
    property real noticeMinutes: 0
    property var snoozeRaw: null
    property int snoozeLast: 0

    signal collapse
    signal picked(int id)
    signal stopRequested(int id)
    signal snoozed(int minutes)

    readonly property string tstate: timer ? timer.state : ""
    readonly property bool ringing: tstate === "ringing"
    readonly property real now: daemon ? daemon.now : 0
    readonly property real remaining: (daemon && timer) ? daemon.remainingOf(timer, now) : 0
    readonly property color accent: tstate === "ringing" ? Theme.error : (daemon && timer ? daemon.colorFor(timer) : Theme.primary)
    readonly property var others: daemon && timer ? (daemon.sorted || []).filter(t => t.id !== timer.id) : []
    readonly property bool renaming: nameField.visible
    readonly property alias glass: bigGlass
    readonly property alias nameInput: nameField
    // Where the keyboard was before the rename field or a button took it
    property var _returnFocus: null

    implicitHeight: main.height + (others.length > 0 ? othersBlock.height + Theme.spacingS : 0)

    // ---- keyboard ------------------------------------------------------

    function controls() {
        const list = [];
        for (const c of [nameBox, muteBtn].concat(adjust.visible ? [adjust.children[0], adjust.children[1], adjust.children[2]] : []).concat([stopRinging]).concat(snoozeRepeater.items()).concat([pauseBtn, replayBtn, closeBtn]))
            if (c && c.visible && c.activeFocusOnTab)
                list.push(c);
        for (let i = 0; i < othersList.count; i++) {
            const it = othersList.itemAtIndex(i);
            if (it)
                list.push(it);
        }
        return list;
    }

    function focusControl(step) {
        const list = controls();
        if (list.length === 0)
            return false;
        let at = list.findIndex(c => c.activeFocus);
        if (at < 0) {
            const w = root.Window.window;
            root._returnFocus = w ? w.activeFocusItem : null;
            at = step > 0 ? -1 : list.length;
        }
        const next = list[(at + step + list.length) % list.length];
        next.forceActiveFocus();
        const mini = list.indexOf(next) - (list.length - othersList.count);
        if (mini >= 0)
            othersList.positionViewAtIndex(mini, ListView.Contain);
        return true;
    }

    // True while one of the controls has the keyboard
    function controlFocused() {
        return controls().some(c => c.activeFocus);
    }

    function giveBackFocus() {
        const back = root._returnFocus;
        root._returnFocus = null;
        if (back && back.forceActiveFocus)
            back.forceActiveFocus();
    }

    function startRename() {
        if (!root.timer)
            return;
        if (!root._returnFocus) {
            const w = root.Window.window;
            root._returnFocus = w ? w.activeFocusItem : null;
        }
        nameField.text = root.daemon.displayLabel(root.timer);
        nameField.visible = true;
        nameField.selectAll();
        nameField.forceActiveFocus();
    }

    // Validates (true) or cancels the rename; a name that cleans to nothing
    // is refused and the field stays open
    function endRename(keep) {
        if (!nameField.visible)
            return;
        if (keep && root.daemon && root.timer) {
            const name = Card.cleanName(nameField.text);
            if (name === "")
                return;
            if (name !== root.daemon.displayLabel(root.timer))
                root.daemon.rename(root.timer.id, name);
        }
        nameField.visible = false;
        root.giveBackFocus();
    }

    function togglePause() {
        if (root.timer && (root.tstate === "running" || root.tstate === "paused"))
            root.daemon.toggle(root.timer.id);
    }

    // A name being typed is kept when the card closes or goes away
    Component.onDestruction: root.endRename(true)

    // Keys reaching the controls (Tab, Space, Escape): the buttons only take
    // Enter, so Space comes up here and pauses whatever has the focus
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.focusControl(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier) ? 1 : -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            root.togglePause();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.giveBackFocus();
            root.collapse();
            event.accepted = true;
        } else if (event.key === Qt.Key_F2) {
            root.startRename();
            event.accepted = true;
        }
    }

    // ---- the card ------------------------------------------------------

    // Narrow (the row shares its width with other cards): the info, the
    // chips and the buttons go under the hourglass, one line each
    readonly property bool narrow: width < 400
    readonly property real glassSize: narrow ? 76 : 100

    Item {
        id: main
        width: parent.width
        height: root.narrow ? root.glassSize + infoRow.height + chipsRow.height + buttons.height + Theme.spacingS * 3 : Math.max(root.glassSize, infoRow.y + infoRow.height + Theme.spacingS + chipsRow.height)

        MiniGlass {
            id: bigGlass
            anchors.left: parent.left
            anchors.leftMargin: root.narrow ? -Theme.spacingXS : 0
            y: root.narrow ? 0 : (parent.height - height) / 2
            size: root.glassSize
            daemon: root.daemon
            timer: root.timer
            animate: root.animate
            accent: root.accent

            HoverHandler {
                id: glassHover
                onHoveredChanged: if (!hovered) glassTip.hide()
            }
            DankTooltipV2 {
                id: glassTip
            }
            Timer {
                interval: 600
                running: glassHover.hovered
                onTriggered: glassTip.show(Card.glassTip(root.timer, root.now, root.use24h), bigGlass, 0, 0, "bottom")
            }
        }

        Column {
            id: info
            anchors.left: bigGlass.right
            anchors.leftMargin: root.narrow ? Theme.spacingXS : Theme.spacingM
            anchors.right: parent.right
            y: root.narrow ? (root.glassSize - height) / 2 : Theme.spacingXS
            spacing: 2

            // Name: a click or F2 renames it
            Item {
                id: nameBox
                objectName: "nameBox"
                width: parent.width
                height: 26
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: root.words.rename + " " + nameText.text
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.startRename();
                        event.accepted = true;
                    }
                }

                StyledText {
                    id: nameText
                    visible: !nameField.visible
                    width: Math.min(implicitWidth, parent.width - collapseBtn.width)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.daemon && root.timer ? root.daemon.displayLabel(root.timer) : ""
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: root.ringing ? Theme.error : Theme.surfaceText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
                Rectangle {
                    anchors.left: nameText.left
                    anchors.right: nameText.right
                    anchors.top: nameText.bottom
                    height: 1
                    color: Theme.outline
                    visible: !nameField.visible && (nameMouse.containsMouse || nameBox.activeFocus)
                }
                MouseArea {
                    id: nameMouse
                    width: nameText.width
                    height: parent.height
                    visible: !nameField.visible
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: root.startRename()
                }

                Rectangle {
                    visible: nameField.visible
                    anchors.fill: nameField
                    anchors.leftMargin: -4
                    anchors.rightMargin: -4
                    anchors.topMargin: -2
                    anchors.bottomMargin: -2
                    radius: 6
                    color: Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: Card.cleanName(nameField.text) === "" ? Theme.error : Theme.primary
                }
                TextInput {
                    id: nameField
                    objectName: "nameField"
                    visible: false
                    x: 4
                    width: parent.width - collapseBtn.width - Theme.spacingS - 4
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: nameText.font.family
                    color: Theme.surfaceText
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    maximumLength: 60
                    clip: true
                    Accessible.name: root.words.rename
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.endRename(true);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.endRename(false);
                            event.accepted = true;
                        }
                    }
                    // A click elsewhere validates
                    onActiveFocusChanged: if (!activeFocus && visible)
                        root.endRename(true)
                }

                CardButton {
                    id: collapseBtn
                    objectName: "collapseButton"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 28
                    iconName: "expand_less"
                    iconColor: Theme.surfaceVariantText
                    tooltip: root.words.collapse
                    activeFocusOnTab: false
                    onClicked: root.collapse()
                }
            }

            StyledText {
                id: bigTime
                objectName: "bigTime"
                text: Card.clock(root.timer, root.now)
                font.pixelSize: root.narrow ? 28 : 36
                font.weight: Font.Medium
                font.features: {
                    "tnum": 1
                }
                color: root.ringing ? Theme.error : (root.tstate === "paused" ? Theme.surfaceVariantText : Theme.surfaceText)
            }
        }

        // End, duration, notice, sound: icons first, text only for numbers
        Row {
            id: infoRow
            x: root.narrow ? 0 : info.x
            y: root.narrow ? root.glassSize + Theme.spacingS : info.y + info.height + 2
            spacing: root.narrow ? Theme.spacingS : Theme.spacingM
            height: 28

            InfoBit {
                visible: root.tstate !== "paused"
                icon: "alarm"
                text: Card.endText(root.timer, root.use24h)
                tip: root.words.ends
            }
            InfoBit {
                visible: root.tstate === "paused"
                icon: "pause"
                text: ""
                tip: root.words.pause
            }
            InfoBit {
                // Narrow: no room, the replay button's tooltip says it
                visible: !root.narrow
                icon: "timer"
                text: Card.shortDuration(root.timer ? root.timer.total : 0)
                tip: root.words.duration
            }
            InfoBit {
                objectName: "noticeBit"
                icon: root.noticeMinutes > 0 ? "notifications" : "notifications_off"
                text: Card.noticeText(root.noticeMinutes)
                tip: root.noticeMinutes > 0 ? root.words.notice : root.words.noNotice
                dim: root.noticeMinutes <= 0
            }
            CardButton {
                id: muteBtn
                objectName: "muteButton"
                anchors.verticalCenter: parent.verticalCenter
                size: 28
                readonly property bool muted: !!(root.timer && root.timer.muted)
                iconName: muted ? "music_off" : "music_note"
                iconColor: muted ? Theme.surfaceVariantText : Theme.surfaceText
                tooltip: muted ? root.words.unmute : root.words.mute
                onClicked: if (root.timer)
                    root.daemon.toggleMute(root.timer.id)
            }
        }

        // Time chips (or Stop and snooze), then the round buttons: on one
        // line when wide, on two when narrow
        Row {
            id: chipsRow
            x: root.narrow ? 0 : info.x
            y: root.narrow ? infoRow.y + infoRow.height + Theme.spacingS : parent.height - height
            height: 36
            spacing: Theme.spacingXS

            AdjustChips {
                id: adjust
                visible: !root.ringing
                daemon: root.daemon
                timer: root.timer
                timerState: root.tstate
                remaining: root.remaining
                short: true
                // Under 1:01, −1 would only hit the 0:10 floor
                minusFrom: 61000
                spacing: Theme.spacingXS
                Component.onCompleted: {
                    for (let i = 0; i < children.length; i++)
                        children[i].activeFocusOnTab = true;
                }
            }

            CardButton {
                id: stopRinging
                objectName: "stopRinging"
                visible: root.ringing
                size: 36
                filled: true
                accent: Theme.error
                iconName: "stop"
                tooltip: root.words.stop
                onClicked: if (root.timer)
                    root.stopRequested(root.timer.id)
            }
            Repeater {
                id: snoozeRepeater
                model: root.ringing ? Card.snoozeChoices(root.snoozeRaw, root.snoozeLast) : []
                function items() {
                    return Array.from({ length: count }, (_, i) => itemAt(i));
                }
                Chip {
                    objectName: "snooze" + modelData
                    required property int modelData
                    required property int index
                    text: "+" + modelData + "m"
                    iconName: index === 0 ? "snooze" : ""
                    activeFocusOnTab: true
                    Accessible.name: root.words.snooze + " " + modelData + " min"
                    onClicked: root.snoozed(modelData)
                }
            }
        }

        Row {
            id: buttons
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 36
            spacing: Theme.spacingXS

            CardButton {
                id: pauseBtn
                objectName: "pauseButton"
                visible: !root.ringing
                filled: true
                accent: root.accent
                iconName: root.tstate === "paused" ? "play_arrow" : "pause"
                tooltip: root.tstate === "paused" ? root.words.resume : root.words.pause
                onClicked: root.togglePause()
            }
            CardButton {
                id: replayBtn
                objectName: "replayButton"
                iconName: "replay"
                tooltip: root.words.restart + (root.timer ? " · " + Card.shortDuration(root.timer.total) : "")
                onClicked: if (root.timer)
                    root.daemon.restart(root.timer.id)
            }
            CardButton {
                id: closeBtn
                objectName: "closeButton"
                visible: !root.ringing
                iconName: "close"
                tooltip: root.words.stop
                onClicked: if (root.timer)
                    root.stopRequested(root.timer.id)
            }
        }
    }

    // ---- the other timers ---------------------------------------------

    Column {
        id: othersBlock
        visible: root.others.length > 0
        anchors.top: main.bottom
        anchors.topMargin: Theme.spacingS
        width: parent.width
        spacing: Theme.spacingXS

        Row {
            width: parent.width
            spacing: Theme.spacingS
            StyledText {
                id: othersTitle
                text: root.words.others
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
            Rectangle {
                anchors.verticalCenter: othersTitle.verticalCenter
                width: parent.width - othersTitle.width - Theme.spacingS
                height: 1
                color: Theme.outlineVariant
            }
        }

        ListView {
            id: othersList
            objectName: "othersList"
            width: parent.width
            height: 44
            orientation: ListView.Horizontal
            spacing: Theme.spacingXS
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.others.map(t => t.id)
            delegate: OtherMini {
                required property int modelData
                daemon: root.daemon
                timerId: modelData
                animate: root.animate
                onPicked: id => root.picked(id)
            }
        }
    }

    component InfoBit: Row {
        id: bit
        property string icon: ""
        property string text: ""
        property string tip: ""
        property bool dim: false
        spacing: 3
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Accessible.role: Accessible.StaticText
        Accessible.name: tip + (text !== "" ? " " + text : "")

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: bit.icon
            size: 16
            color: Theme.surfaceVariantText
            opacity: bit.dim ? 0.6 : 1
        }
        StyledText {
            visible: bit.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: bit.text
            font.pixelSize: Theme.fontSizeSmall
            font.features: {
                "tnum": 1
            }
            color: Theme.surfaceVariantText
        }
        HoverHandler {
            id: bitHover
            onHoveredChanged: if (!hovered) bitTip.hide()
        }
        DankTooltipV2 {
            id: bitTip
        }
        Timer {
            interval: 600
            running: bitHover.hovered && bit.tip !== ""
            onTriggered: bitTip.show(bit.tip, bit, 0, 0, "bottom")
        }
    }
}
