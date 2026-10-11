import QtQuick
import qs.Common
import "../../.."

// One settings page at a given width, filled from a made-up store.
Item {
    property alias pageWidth: page.width
    property alias preset: page.store
    readonly property alias page: page
    width: page.width
    height: page.height

    // The page paints no background of its own: the settings panel does
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    TimerSettings {
        id: page
    }
}
