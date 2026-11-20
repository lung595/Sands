pragma Singleton
import QtQuick

// Preview stand-in: the scene sets these before it loads the plugin.
QtObject {
    property bool reduceMotion: Qt.application.arguments.indexOf("reduce") >= 0
    property bool use24HourClock: true
    property var pluginSettings: ({})
    // No bar holds the widget: the settings open on Getting started
    property var barConfigs: []
    function getPluginSettingsForPlugin(id) {
        return pluginSettings[id] || {};
    }
}
