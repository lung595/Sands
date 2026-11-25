pragma Singleton
import QtQuick

// Preview stand-in: the scene sets these before it loads the plugin.
QtObject {
    property bool reduceMotion: Qt.application.arguments.indexOf("reduce") >= 0
    property bool use24HourClock: true
    property var pluginSettings: ({})
    // No bar holds the widget: the settings open on Getting started
    property var barConfigs: []
    // How many times the settings were written (the daemon e2e test reads it)
    property int pluginSettingsSaves: 0
    function savePluginSettings() {
        pluginSettingsSaves++;
    }
}
