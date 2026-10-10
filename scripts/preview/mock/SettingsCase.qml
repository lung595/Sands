import QtQuick
import "../../.."

// One settings page at a given width, filled from a made-up store.
Item {
    property alias pageWidth: page.width
    property alias preset: page.store
    readonly property alias page: page
    width: page.width
    height: page.height

    TimerSettings {
        id: page
    }
}
