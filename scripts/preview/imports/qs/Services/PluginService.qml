pragma Singleton
import QtQuick

// Preview stand-in: the scene puts its fake daemon here, where the widget
// looks for the real one, and says which plugins count as loaded.
QtObject {
    property var pluginDaemonInstances: ({})
    property var loadedIds: []
    property var globalVars: ({})

    signal pluginLoaded(string pluginId)
    signal pluginUnloaded(string pluginId)
    signal globalVarChanged(string pluginId, string varName)
    // Declared by every DMS, live launcher sections or not (an older one runs
    // the open search again when it fires)
    signal requestLauncherUpdate(string pluginId)

    // No prefix set, like the default install
    function getPluginTrigger(id) {
        return "";
    }

    function isPluginLoaded(id) {
        return loadedIds.indexOf(id) >= 0;
    }

    function getGlobalVar(id, name, fallback) {
        return globalVars[id] && name in globalVars[id] ? globalVars[id][name] : fallback;
    }

    function setGlobalVar(id, name, value) {
        const next = Object.assign({}, globalVars);
        next[id] = Object.assign({}, next[id] || {}, {
            [name]: value
        });
        globalVars = next;
        globalVarChanged(id, name);
    }
}
