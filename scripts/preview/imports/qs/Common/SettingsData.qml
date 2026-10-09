pragma Singleton
import QtQuick

// Preview stand-in: the scene sets these before it loads the plugin.
QtObject {
    property bool reduceMotion: false
    property bool use24HourClock: true
    property var pluginSettings: ({})
    function getPluginSettingsForPlugin(id) {
        return pluginSettings[id] || {};
    }
}
