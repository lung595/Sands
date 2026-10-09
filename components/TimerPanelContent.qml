import QtQuick
import qs.Common

// Panel content: hourglass, time, controls, other timers.
Column {
    id: pop

    property var daemon: null
    property bool use24h: true
    // 0 → 1: freeze (pause), driven by the panel
    // Frost: always an ice blue (cold means blue), but its lightness follows
    // the theme: pale on a dark theme, deeper on a light one so it stays visible.
    readonly property color frostColor: Qt.hsla(0.56, 0.85, Math.max(0.45, Math.min(0.88, Theme.surfaceText.hslLightness)), 1)
    // Freeze: sets in ~0.9 s on pause, melts in ~0.7 s on resume.
    property real frost: st === "paused" ? 1 : 0
    Behavior on frost {
        NumberAnimation {
            duration: pop.st === "paused" ? 900 : 700
            easing.type: Easing.InOutCubic
        }
    }

    // false when the panel is closed: every animation stops.
    property bool shown: true
    // Tells the daemon a panel is on screen, so its notes land here
    // instead of in a toast.
    readonly property bool live: shown && !!daemon
    onLiveChanged: if (daemon)
        daemon.panelShown(pop, live)
    Component.onDestruction: if (daemon)
        daemon.panelShown(pop, false)
    readonly property bool reducedMotion: SettingsData.reduceMotion

    // Timer shown large: the one picked, otherwise the nearest.
    property int selectedId: -1
    readonly property var d: pop.daemon
    readonly property var t: {
        const sel = d ? d.find(selectedId) : null;
        return sel || (d ? d.primary : null);
    }
    readonly property string st: t ? t.state : "idle"
    readonly property real rem: (t && d) ? d.remainingOf(t) : 0
    readonly property var others: (d && t) ? d.sorted.filter(x => x.id !== t.id) : []
    // Text key: only changes when the list changes, not on every clock tick
    // (otherwise the Repeater would recreate its rows 4 times per second).
    readonly property string othersKey: others.map(x => x.id).join(",")
    readonly property color accent: (d && t) ? d.colorFor(t) : Theme.primary
    // Text on the main button: the theme's own for the first timer, and for
    // the derived hues a darker or lighter shade of the button itself.
    readonly property color accentText: {
        if (!t || !t.hue)
            return Theme.onPrimary;
        const lum = 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b;
        return lum > 0.6 ? Qt.darker(accent, 4) : Qt.lighter(accent, 4);
    }

    // --- Switching between timers (swipe, horizontal wheel, dots)
    readonly property var ids: d ? d.sorted.map(x => x.id) : []
    readonly property int index: t ? ids.indexOf(t.id) : -1
    property real slide: 0

    function go(step) {
        if (ids.length < 2 || switchAnim.running)
            return;
        showId(ids[(index + step + ids.length) % ids.length], step);
    }
    function showId(id, dir) {
        if (!t || id === t.id)
            return;
        switchAnim.dir = dir;
        switchAnim.nextId = id;
        switchAnim.restart();
    }
    SequentialAnimation {
        id: switchAnim
        property int dir: 1
        property int nextId: -1
        NumberAnimation {
            target: pop
            property: "slide"
            to: -switchAnim.dir
            duration: pop.reducedMotion ? 0 : 130
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                pop.selectedId = switchAnim.nextId;
                pop.slide = switchAnim.dir;
            }
        }
        NumberAnimation {
            target: pop
            property: "slide"
            to: 0
            duration: pop.reducedMotion ? 0 : 240
            easing.type: Easing.OutCubic
        }
    }

    width: 340
    spacing: Theme.spacingL
    topPadding: Theme.spacingS
    bottomPadding: Theme.spacingXS

    // Space pauses / resumes the shown timer (stops it if it is ringing),
    // like the big button. It is a window shortcut, not a Keys handler: DMS
    // gives the keyboard focus to its own popout container, which is an
    // ancestor of this panel, and a key event only ever travels upwards, so
    // a Keys handler here would never see it.
    focus: true
    onShownChanged: if (shown)
        forceActiveFocus()

    Shortcut {
        sequence: "Space"
        context: Qt.WindowShortcut
        // Only while the panel is open and has a timer to act on.
        enabled: pop.shown && !!pop.t && !!pop.d
        onActivated: pop.d.toggle(pop.t.id)
    }

    // Opening the popout silences the alarm; the timer stays "finished"
    // so the user can choose: stop, +1 min, restart. It also registers
    // the panel with the daemon (see `live`).
    Component.onCompleted: {
        d?.silence();
        if (daemon)
            daemon.panelShown(pop, live);
    }
    onVisibleChanged: if (visible)
        d?.silence()

    PanelGlass {
        id: glassArea
        width: parent.width
        opacity: 1 - Math.abs(pop.slide)
        transform: Translate {
            x: pop.slide * 56
        }
        daemon: pop.d
        timer: pop.t
        timerState: pop.st
        remaining: pop.rem
        accent: pop.accent
        frost: pop.frost
        frostColor: pop.frostColor
        reducedMotion: pop.reducedMotion
        animate: pop.shown
        topInset: pop.topPadding
        ids: pop.ids
        index: pop.index
        onSwitchTimer: step => pop.go(step)
        onPickTimer: (id, dir) => pop.showId(id, dir)
        // One minute per wheel notch, never below the last minute.
        onAddMinute: step => {
            if (step > 0 || pop.rem > 61000)
                pop.d.adjust(pop.t.id, step * 60000);
        }
    }

    PanelClock {
        width: parent.width
        opacity: 1 - Math.abs(pop.slide)
        transform: Translate {
            x: pop.slide * 40
        }
        daemon: pop.d
        timer: pop.t
        timerState: pop.st
        remaining: pop.rem
        frost: pop.frost
        frostColor: pop.frostColor
        fxTime: glassArea.fxTime
        use24h: pop.use24h
    }

    AdjustChips {
        anchors.horizontalCenter: parent.horizontalCenter
        daemon: pop.d
        timer: pop.t
        timerState: pop.st
        remaining: pop.rem
    }

    PanelControls {
        width: parent.width
        daemon: pop.d
        timer: pop.t
        timerState: pop.st
        accent: pop.accent
        accentText: pop.accentText
    }

    // Built only while there are other timers.
    Loader {
        width: parent.width
        active: pop.others.length > 0
        visible: active
        sourceComponent: OtherTimers {
            daemon: pop.d
            idsKey: pop.othersKey
            onPicked: id => pop.showId(id, 1)
        }
    }
}
