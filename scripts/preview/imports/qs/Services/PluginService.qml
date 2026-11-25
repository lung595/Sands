pragma Singleton
import QtQuick

// Preview stand-in: the scene puts its fake daemon here, where the widget
// looks for the real one.
QtObject {
    property var pluginDaemonInstances: ({})

    // Declared by every DMS, live launcher sections or not (an older one runs
    // the open search again when it fires)
    signal requestLauncherUpdate(string pluginId)

    // No prefix set, like the default install
    function getPluginTrigger(id) {
        return "";
    }
}
