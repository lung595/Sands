import QtQuick

// The link under the panel that opens the time journal, and brings the timers back.
LinkButton {

    property bool open: false
    signal toggled

    caption: open ? "Back to timers" : "This week"
    onClicked: toggled()
}
