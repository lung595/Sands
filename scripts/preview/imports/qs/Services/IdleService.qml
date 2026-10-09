pragma Singleton
import QtQuick

// Preview stand-in: screens are always awake in a picture.
QtObject {
    property bool isShellLocked: false
    property bool monitorsOff: false
}
