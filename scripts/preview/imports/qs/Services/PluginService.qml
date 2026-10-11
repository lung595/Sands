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

    // A mocked Alex for the timer-end row: `dms ipc call alex timerEndMode [mode]`
    // answers like the real one, and every call is kept for the scene to assert.
    property string alexMode: "react"
    property var dmsCalls: []

    function dms(command) {
        dmsCalls = dmsCalls.concat([command.slice(1)]);
        if (!isPluginLoaded("alex"))
            return "Target not found.";
        if (command.length === 6) {
            alexMode = command[5];
            setGlobalVar("alex", "timerEndModeChanged", {
                kind: "timerEndModeChanged",
                mode: alexMode
            });
            return "ok";
        }
        return alexMode;
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
