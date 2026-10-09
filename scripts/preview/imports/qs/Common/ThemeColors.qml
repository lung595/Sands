import QtQuick

// Holds `onPrimary` and `onError` apart from Theme.qml. Declared in the same
// object as `primary` and `error`, QML reads them as signal handlers and
// refuses to load the file without saying why. The real shell's Theme is a
// Quickshell Singleton, which does not have the problem.
QtObject {
    property color onPrimary: "#381E72"
    property color onError: "#601410"
}
