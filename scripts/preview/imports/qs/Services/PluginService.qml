pragma Singleton
import QtQuick

// Preview stand-in: the scene puts its fake daemon here, where the widget
// looks for the real one.
QtObject {
    property var pluginDaemonInstances: ({})
}
