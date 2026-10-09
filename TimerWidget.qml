import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"

// Bar pill + popout. State lives in the daemon; this file only
// displays it and forwards actions.
PluginComponent {
    id: root

    pluginId: "smartTimer"
    pluginService: PluginService
    layerNamespacePlugin: "smart-timer"

    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null
    readonly property bool hasTimers: daemon?.hasTimers ?? false
    readonly property var primary: daemon?.primary ?? null
    readonly property bool use24h: SettingsData.use24HourClock !== false
    // Locked session or screens off: nobody sees the pill, so it stops
    // moving (the alarm sound still rings).
    readonly property bool asleep: SessionService.locked || IdleService.isShellLocked || IdleService.monitorsOff

    // Invisible at rest: the pill appears (width + fade) with the first timer.
    function syncVisibility() {
        setVisibilityOverride(root.hasTimers);
        if (!root.hasTimers)
            root.closePopout();
    }
    onHasTimersChanged: syncVisibility()
    Component.onCompleted: syncVisibility()

    // Keyboard shortcut / IPC: opens the panel on the active screen.
    Connections {
        target: root.daemon
        function onPanelRequested(screenName) {
            if (!screenName || (root.parentScreen && root.parentScreen.name === screenName))
                root.triggerPopout();
        }
    }

    // Left click: opens the panel.
    // Right click: pause / resume the nearest one; while ringing, stops it.
    pillRightClickAction: () => {
        if (!root.daemon)
            return;
        if (root.daemon.ringing)
            root.daemon.dismissRinging();
        else if (root.primary)
            root.daemon.toggle(root.primary.id);
    }

    // The bar can open panels on hover: not for the timer. Hovering
    // only shows its name in the pill; the panel opens
    // on click. (DMS calls this function on hover; we neutralize it.)
    function triggerHoverPopout(widgetHostId) {
    }

    // ------------------------------------------------------------------
    // Pill
    // ------------------------------------------------------------------

    horizontalBarPill: Component {
        HorizontalPill {
            daemon: root.daemon
            asleep: root.asleep
            barThickness: root.barThickness
            widgetThickness: root.widgetThickness
            barConfig: root.barConfig
        }
    }

    verticalBarPill: Component {
        VerticalPill {
            daemon: root.daemon
            barThickness: root.barThickness
            barConfig: root.barConfig
        }
    }

    // ------------------------------------------------------------------
    // Panel (native DMS popout)
    // ------------------------------------------------------------------

    popoutWidth: 356
    popoutHeight: 560

    popoutContent: Component {
        Item {
            id: pane

            property var closePopout: null
            property var parentPopout: null

            width: parent ? parent.width : root.popoutWidth
            implicitHeight: content.implicitHeight

            TimerPanelContent {
                id: content
                width: pane.width
                daemon: root.daemon
                use24h: root.use24h
                // Panel closed (DMS keeps its content loaded): no more animation.
                shown: pane.parentPopout ? pane.parentPopout.shouldBeVisible : true
            }

            // Why something did not happen, over the top of the hourglass:
            // the bottom of the panel can be off screen with a long list
            HelpNote {
                daemon: root.daemon
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingM
                maxWidth: pane.width - Theme.spacingM * 2
            }
        }
    }
}
