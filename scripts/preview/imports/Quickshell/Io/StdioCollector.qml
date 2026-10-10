import QtQuick

// Preview stand-in: the scan never runs here, so nothing is ever collected.
QtObject {
    property string text: ""
    signal streamFinished
}
