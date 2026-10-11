pragma Singleton
import QtQuick

// Preview stand-in for the DMS theme: only what Sands reads, with the
// default dark palette. Not loaded by the plugin.
ThemeColors {
    id: root
    // `light` among the arguments switches the whole preview to a light palette
    lightMode: light
    readonly property bool light: Qt.application.arguments.indexOf("light") >= 0
    property color primary: root.light ? "#6750A4" : "#D0BCFF"
    property color error: root.light ? "#B3261E" : "#F2B8B5"
    property color warning: root.light ? "#8A5100" : "#FFB95C"
    property color success: root.light ? "#1B6E2E" : "#8FD99A"
    property color outline: root.light ? "#79747E" : "#938F99"
    property color outlineVariant: root.light ? "#CAC4D0" : "#49454F"
    property color primaryText: root.light ? "#FFFFFF" : "#381E72"
    property color surface: root.light ? "#FEF7FF" : "#141218"
    property color surfaceContainer: root.light ? "#F3EDF7" : "#211F26"
    property color surfaceContainerHigh: root.light ? "#ECE6F0" : "#2B2930"
    property color surfaceContainerHighest: root.light ? "#E6E0E9" : "#36343B"
    property color surfaceText: root.light ? "#1D1B20" : "#E6E0E9"
    property color surfaceVariantText: root.light ? "#49454F" : "#CAC4D0"
    property color surfaceTextHover: Qt.rgba(0.9, 0.88, 0.91, 0.08)
    property color widgetTextColor: root.light ? "#1D1B20" : "#E6E0E9"
    property real fontSizeSmall: 12
    property real fontSizeMedium: 14
    property real fontSizeLarge: 16
    property real fontSizeXLarge: 20
    property real iconSize: 24
    property real iconSizeSmall: 16
    property real spacingXS: 4
    property real spacingS: 8
    property real spacingM: 12
    property real spacingL: 16
    property real spacingXL: 24
    property real cornerRadius: 12
    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function barTextSize(thickness, fontScale, maximize) {
        return fontScale ? 13 * fontScale : 13;
    }
}
