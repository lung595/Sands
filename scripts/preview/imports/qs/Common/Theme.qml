pragma Singleton
import QtQuick

// Preview stand-in for the DMS theme: only what Sands reads, with the
// default dark palette. Not loaded by the plugin.
ThemeColors {
    property color primary: "#D0BCFF"
    property color error: "#F2B8B5"
    property color warning: "#FF9800"
    property color outline: "#938F99"
    property color surface: "#141218"
    property color surfaceContainer: "#211F26"
    property color surfaceContainerHigh: "#2B2930"
    property color surfaceContainerHighest: "#36343B"
    property color surfaceText: "#E6E0E9"
    property color surfaceVariantText: "#CAC4D0"
    property color surfaceTextHover: Qt.rgba(0.9, 0.88, 0.91, 0.08)
    property color widgetTextColor: "#E6E0E9"
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
