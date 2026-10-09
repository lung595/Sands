import QtQuick

// Preview stand-in for the DMS host of a bar widget: the same properties and
// hooks Sands uses, none of the bar. The scene loads the pill and the popout
// components this item receives.
Item {
    property string pluginId: ""
    property var pluginService: null
    property string layerNamespacePlugin: ""
    property real barThickness: 40
    property real widgetThickness: 30
    property var barConfig: ({})
    property var parentScreen: null
    property real popoutWidth: 400
    property real popoutHeight: 0
    property var pillRightClickAction: null
    property Component horizontalBarPill
    property Component verticalBarPill
    property Component popoutContent

    function setVisibilityOverride(visible) {
    }
    function closePopout() {
    }
    function triggerPopout() {
    }
    function triggerHoverPopout(widgetHostId) {
    }
}
