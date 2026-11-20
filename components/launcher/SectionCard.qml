pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "Card.js" as Card

// One card of the "Timers" row of the launcher, drawn by DMS for each item
// of TimerLauncher.getSectionItems() (Section.js). DMS sets launcherItem (its
// item, with what Section.js built under `data`), selected and expanded;
// implicitHeight is the height of the row, handleKey() gets the keys first
// while the card is open. The countdown is bound to the daemon here, so the
// row is never refreshed for the clock.
//
// Kinds: a timer (collapsed, or open: ExpandedTimer), a ringing timer (Enter
// stops it, a click opens it), a favourite (Enter starts it), "+N" (opens
// the 5th timer, the others below it) and "Stopped · Undo" for 5 s.
Item {
    id: root

    property var launcherItem: null
    property bool selected: false
    property bool expanded: false

    // Set by TimerLauncher (a preview or a test sets them by hand)
    property var daemon: null
    property var host: null
    // The Sands setting "Animate the hourglasses"
    property bool animateSetting: true
    // The DMS language (TimerLauncher passes it), else the system's
    property string lang: Qt.locale().name

    readonly property var entry: launcherItem ? (launcherItem.data || launcherItem) : ({})
    readonly property string kind: entry.kind || "timer"
    readonly property var words: Card.words(lang)
    readonly property bool use24h: SettingsData.use24HourClock !== false
    // Everything still with Reduce motion or the setting off: the sand
    // follows the level once a second, nothing else moves
    readonly property bool motion: animateSetting && !SettingsData.reduceMotion
    // ... and only while the launcher is on screen
    readonly property bool animate: motion && visible && (!Window.window || Window.window.visible)

    // A mini-card picked in "Other timers" that is not a card of the row
    property int pickedId: -1
    // (once it is gone, stopped, the card is its own timer again, still open)
    readonly property int timerId: pickedId >= 0 && daemon && daemon.find(pickedId) ? pickedId : (entry.timerId !== undefined ? entry.timerId : -1)
    readonly property var timer: daemon && timerId >= 0 ? daemon.find(timerId) : null
    readonly property string tstate: kind === "stopped" ? "stopped" : (timer ? timer.state : "")
    readonly property bool ringing: tstate === "ringing"
    readonly property bool open: (expanded || localOpen) && (kind === "timer" || kind === "more") && !!timer
    // Without DMS's controller (a test, a preview), a ringing card opens here
    property bool localOpen: false
    readonly property real now: daemon ? daemon.now : 0

    readonly property int collapsedHeight: 64

    Accessible.role: Accessible.Button
    Accessible.name: kind === "stopped" ? (entry.name + " · " + words.stopped) : (timer ? Card.title(timer, now) : (entry.name || ""))

    implicitWidth: 180
    implicitHeight: open ? Theme.spacingM * 2 + 4 + expandedLoader.height : collapsedHeight
    Behavior on implicitHeight {
        enabled: root.motion
        NumberAnimation {
            duration: 420
            // Material 3 spatial spring: fast, a slight overshoot
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }

    onExpandedChanged: {
        if (!expanded) {
            pickedId = -1;
            localOpen = false;
        }
        _hold();
    }
    onOpenChanged: _hold()
    onTimerIdChanged: if (pickedId >= 0 && timerId !== pickedId)
        Qt.callLater(root._dropPicked)
    function _dropPicked() {
        if (pickedId >= 0 && !(daemon && daemon.find(pickedId)))
            pickedId = -1;
    }

    // ---- what the card does ---------------------------------------------

    // DMS's launcher controller, found up the tree (null outside DMS)
    function _controller() {
        for (let p = root.parent; p; p = p.parent) {
            const c = _controllerOf(p);
            if (c && c.expandedItemId !== undefined)
                return c;
        }
        return null;
    }
    // (ResultsList's own property: unknown to the type of an Item)
    function _controllerOf(item) {
        return item.controller;
    }

    function _hold() {
        if (root.host && root.host.holdCard)
            root.host.holdCard(root, root.open || hover.hovered);
    }

    // Moves DMS's selection to the card `itemId`, as its own click does, so
    // Enter and the border follow the open card
    function _select(c, itemId) {
        const i = (c.flatModel || []).findIndex(e => e && !e.isHeader && e.item && e.item.id === itemId);
        if (i >= 0 && typeof c.selectIndex === "function")
            c.selectIndex(i);
    }

    // Opens this card, or the card of timer `id` when it is one of the row
    function openTimer(id) {
        const c = _controller();
        const prefix = Card.idPrefix(root.launcherItem ? root.launcherItem.id : "", root.entry.id);
        const key = prefix + "timer:" + id;
        if (c && id !== root.entry.timerId && (c.sections || []).some(s => (s.items || []).some(i => i.id === key))) {
            _select(c, key);
            c.expandedItemId = key;
            return;
        }
        root.pickedId = id === root.entry.timerId ? -1 : id;
        if (c && root.launcherItem)
            _select(c, root.launcherItem.id);
        if (!root.expanded) {
            if (c && root.launcherItem)
                c.expandedItemId = root.launcherItem.id;
            else
                root.localOpen = true;
        }
    }

    function collapse() {
        const ex = expandedLoader.item as ExpandedTimer;
        if (ex)
            ex.endRename(true);
        const c = _controller();
        if (c && root.expanded)
            c.expandedItemId = "";
        root.localOpen = false;
        root.pickedId = -1;
    }

    // Stop: no question, the card says "Stopped · Undo" for 5 s
    function stop(id) {
        if (root.daemon)
            root.daemon.remove(id);
    }

    function undo() {
        if (root.daemon && root.entry.timerId !== undefined)
            root.daemon.undoRemove(root.entry.timerId);
    }

    function snooze(minutes) {
        if (!root.timer)
            return;
        const svc = root.daemon.pluginService;
        if (svc && svc.savePluginData)
            svc.savePluginData("smartTimer", "snoozeLast", minutes);
        root.daemon.adjust(root.timer.id, minutes * 60000);
    }

    function _setting(key, fallback) {
        return root.daemon && typeof root.daemon.setting === "function" ? root.daemon.setting(key, fallback) : fallback;
    }

    // Keys DMS hands over while the card is open: true when used here.
    // Tab goes into the controls, F2 renames; Escape, Enter, arrows and
    // letters are DMS's (collapse, move, search).
    function handleKey(event) {
        const ex = expandedLoader.item as ExpandedTimer;
        if (!root.open || !ex)
            return false;
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            return ex.focusControl(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier) ? 1 : -1);
        const action = Card.keyAction(event.key === Qt.Key_F2 ? "F2" : (event.key === Qt.Key_Space ? "Space" : ""), ex.renaming ? "name" : (ex.controlFocused() ? "controls" : ""), root.tstate);
        if (action === "rename") {
            ex.startRename();
            return true;
        }
        if (action === "pause") {
            ex.togglePause();
            return true;
        }
        return false;
    }

    // Stopped, then the launcher closed before the undo window ended: a
    // toast tells it, with the command that brings the timer back
    Component.onDestruction: {
        if (root.kind === "stopped" && root.entry.at && Date.now() - root.entry.at < 4500 && typeof ToastService !== "undefined" && ToastService.showInfo)
            ToastService.showInfo(Card.stoppedToast(root.entry.name || "", root.lang), "", Card.UNDO_COMMAND);
        if (root.host && root.host.holdCard)
            root.host.holdCard(root, false);
    }

    HoverHandler {
        id: hover
        onHoveredChanged: root._hold()
    }

    // An open card keeps its clicks: DMS's own click under it would run the
    // item (stop a ringing timer, close the card). Only the controls act.
    MouseArea {
        objectName: "openBody"
        anchors.fill: parent
        enabled: root.open
    }

    // ---- drawing --------------------------------------------------------

    // A collapsed card keeps its own height when an open one makes the row
    // higher (DMS gives every card the row's height)
    Rectangle {
        id: bg
        x: 2
        y: 2
        width: parent.width - 4
        height: (root.open ? parent.height : Math.min(parent.height, root.collapsedHeight)) - 4
        radius: Theme.cornerRadius
        clip: true
        color: root.selected ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        border.width: root.selected ? 2 : 0
        border.color: root.ringing ? Theme.error : Theme.primary
        opacity: root.kind === "favourite" ? 0.72 : 1

        // One soft pulse when it starts ringing, then still
        Rectangle {
            id: pulse
            anchors.fill: parent
            radius: parent.radius
            color: Theme.error
            opacity: 0
            SequentialAnimation {
                id: pulseAnim
                objectName: "pulse"
                NumberAnimation {
                    target: pulse
                    property: "opacity"
                    to: 0.22
                    duration: 450
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pulse
                    property: "opacity"
                    to: 0
                    duration: 900
                    easing.type: Easing.InOutCubic
                }
            }
        }

        // -- collapsed: a timer, a favourite, a ringing one ---------------
        Item {
            id: collapsed
            visible: !root.open && root.kind !== "more" && root.kind !== "stopped"
            x: Theme.spacingS
            width: parent.width - Theme.spacingS * 2
            height: root.collapsedHeight - 4

            MiniGlass {
                id: smallGlass
                objectName: "smallGlass"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: 42
                daemon: root.daemon
                timer: root.kind === "favourite" ? null : root.timer
                animate: root.animate && collapsed.visible
                accent: root.daemon && root.timer && root.daemon.colorFor ? root.daemon.colorFor(root.timer) : Theme.primary
            }

            Column {
                anchors.left: smallGlass.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: trailing.left
                anchors.rightMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // "Pâtes", em dash, "12:34": the name gives way, never the time
                Item {
                    width: parent.width
                    height: timeLbl.implicitHeight
                    StyledText {
                        id: nameLbl
                        objectName: "nameLabel"
                        width: Math.min(implicitWidth, parent.width - timeLbl.implicitWidth)
                        text: root.kind === "favourite" ? (root.entry.name || "") : (root.daemon && root.timer ? root.daemon.displayLabel(root.timer) + Card.SEP : "")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: root.ringing ? Theme.error : Theme.surfaceText
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                    StyledText {
                        id: timeLbl
                        objectName: "timeLabel"
                        anchors.left: nameLbl.right
                        text: root.kind === "favourite" ? "" : Card.clock(root.timer, root.now)
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        font.features: {
                            "tnum": 1
                        }
                        color: root.ringing ? Theme.error : (root.tstate === "paused" ? Theme.surfaceVariantText : Theme.surfaceText)
                        wrapMode: Text.NoWrap
                    }
                }

                Row {
                    spacing: 3
                    height: 16
                    DankIcon {
                        objectName: "line2Icon"
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.kind === "favourite" ? "timer" : (root.tstate === "paused" ? "pause" : "alarm")
                        size: 14
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        objectName: "line2Text"
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.kind === "favourite" ? Card.shortDuration(root.entry.ms) : Card.endText(root.timer, root.use24h)
                        font.pixelSize: Theme.fontSizeSmall
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.surfaceVariantText
                    }
                    // A plan: one dot per step, the done ones filled
                    Repeater {
                        model: Card.planDots(root.timer ? root.timer.plan : null)
                        Rectangle {
                            required property bool modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: modelData ? Theme.primary : "transparent"
                            border.width: 1
                            border.color: Theme.primary
                        }
                    }
                }
            }

            Item {
                id: trailing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root.ringing ? stopBtn.width : 0
                height: 36

                // Ringing: stop with the mouse without opening
                CardButton {
                    id: stopBtn
                    objectName: "stopButton"
                    visible: root.ringing
                    anchors.verticalCenter: parent.verticalCenter
                    filled: true
                    accent: Theme.error
                    iconName: "stop"
                    tooltip: root.words.stop
                    onClicked: if (root.timer)
                        root.stop(root.timer.id)
                }
            }

            // Ringing: the click opens the card (Enter stops it, DMS's side)
            MouseArea {
                visible: root.ringing && !root.open
                anchors.fill: parent
                anchors.rightMargin: trailing.width + Theme.spacingXS
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openTimer(root.entry.timerId)
            }
        }

        // -- "+N": the hidden timers ----------------------------------------
        Row {
            visible: root.kind === "more" && !root.open
            anchors.centerIn: parent
            spacing: Theme.spacingXS
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "hourglass_empty"
                size: Theme.iconSize
                color: Theme.surfaceVariantText
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.entry.name || ""
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
        }

        // -- Stopped · Undo -------------------------------------------------
        Item {
            visible: root.kind === "stopped"
            x: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            height: root.collapsedHeight - 4

            Row {
                anchors.left: parent.left
                anchors.right: undoChip.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                clip: true
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "timer_off"
                    size: 18
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.entry.name || "") + " · " + root.words.stopped
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }
            Rectangle {
                id: undoChip
                objectName: "undoChip"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: undoRow.implicitWidth + Theme.spacingM * 2
                height: 32
                radius: 16
                color: undoMouse.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary
                Accessible.role: Accessible.Button
                Accessible.name: root.words.undo
                Row {
                    id: undoRow
                    anchors.centerIn: parent
                    spacing: 4
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "undo"
                        size: 16
                        color: Theme.primaryText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.words.undo
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.primaryText
                    }
                }
                MouseArea {
                    id: undoMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.undo()
                }
            }
        }

        // -- open -----------------------------------------------------------
        Loader {
            id: expandedLoader
            objectName: "expandedLoader"
            active: root.open
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            height: implicitHeight
            opacity: active ? 1 : 0
            sourceComponent: ExpandedTimer {
                daemon: root.daemon
                timer: root.timer
                words: root.words
                use24h: root.use24h
                animate: root.animate
                noticeMinutes: Card.noticeMinutes(root.timer, root._setting("noticeMinutes", undefined))
                snoozeRaw: root._setting("snooze", null)
                snoozeLast: Number(root._setting("snoozeLast", 0)) || 0
                onCollapse: root.collapse()
                onPicked: id => root.openTimer(id)
                onStopRequested: id => root.stop(id)
                onSnoozed: m => root.snooze(m)
            }
        }
    }

    // While a name is typed, a press anywhere else on the card validates it
    // (the press then goes on to what is under it)
    MouseArea {
        id: renameCatcher
        anchors.fill: parent
        z: 10
        readonly property var ex: expandedLoader.item as ExpandedTimer
        enabled: !!ex && ex.renaming
        onPressed: mouse => {
            const f = ex.nameInput;
            const p = mapToItem(f, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > f.width || p.y > f.height)
                ex.endRename(true);
            mouse.accepted = false;
        }
    }

    function _pulse() {
        if (root.ringing && root.motion)
            pulseAnim.restart();
    }
    onRingingChanged: _pulse()
    Component.onCompleted: _pulse()
}
