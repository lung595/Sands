import QtQuick

// Holds `onPrimary` and `onError` apart from Theme.qml. Declared in the same
// object as `primary` and `error`, QML reads them as signal handlers and
// refuses to load the file without saying why. The real shell's Theme is a
// Quickshell Singleton, which does not have the problem.
QtObject {
    // Set by Theme.qml: the on-colours differ between the light and dark palettes
    property bool lightMode: false
    property color onPrimary: lightMode ? "#FFFFFF" : "#381E72"
    property color primaryText: onPrimary
    property color onError: lightMode ? "#FFFFFF" : "#601410"
}
