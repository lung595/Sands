import QtQuick

// Preview stand-in: the manifest is always there, nothing is read.
QtObject {
    property string path: ""
    property bool blockLoading: false
    property bool loaded: true
}
