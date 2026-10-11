import QtQuick
import Quickshell.Io
import qs.Services
import "../../AlexBridge.js" as AlexBridge

// The timer-end mode as Alex keeps it (Q151): read once when this exists, then
// followed through the « mode changed » notice. Nothing is stored here, and it
// only lives while the settings page does.
Item {
    id: root

    // Alex is loaded; kept current by the load and unload signals
    property bool loaded: false
    // The mode Alex reported, "" while unread or unreadable
    property string mode: ""

    // Ask Alex to change; refused when the value is not one of the three words
    function request(value) {
        const args = AlexBridge.setArgs(value);
        if (args === null || setter.running)
            return;
        setter.args = args;
        setter.running = true;
    }

    function _read() {
        if (loaded && !reader.running)
            reader.running = true;
    }

    Component.onCompleted: loaded = PluginService.isPluginLoaded(AlexBridge.ALEX_ID)
    onLoadedChanged: {
        mode = "";
        _read();
    }

    Connections {
        target: PluginService

        function onPluginLoaded(id) {
            if (id === AlexBridge.ALEX_ID)
                root.loaded = true;
        }

        function onPluginUnloaded(id) {
            if (id === AlexBridge.ALEX_ID)
                root.loaded = false;
        }

        // The notice is followed only while Alex is there
        function onGlobalVarChanged(id, name) {
            if (!root.loaded || id !== AlexBridge.ALEX_ID || name !== AlexBridge.MODE_CHANGED_KIND)
                return;
            const value = AlexBridge.noticeMode(PluginService.getGlobalVar(id, name, null));
            if (value !== "")
                root.mode = value;
        }
    }

    Process {
        id: reader
        command: ["dms"].concat(AlexBridge.readArgs())
        stdout: StdioCollector {
            onStreamFinished: root.mode = AlexBridge.parseReply(text)
        }
    }

    Process {
        id: setter
        property var args: null
        command: ["dms"].concat(args ?? [])
        // Alex answers with the notice; if it does not, ask again for the truth
        onExited: root._read()
    }
}
