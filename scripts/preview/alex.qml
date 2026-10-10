import QtQuick
import QtQuick.Window
import "../.."

// Offscreen check of the Alex bridge in the real TimerDaemon, with a mock
// PluginService that counts calls. Exits 0 when every assertion holds.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports alex.qml -- <present|absent> /dev/null
Window {
    id: win

    readonly property bool present: Qt.application.arguments[Qt.application.arguments.length - 2] === "present"
    property int globalCalls: 0
    property int alexReads: 0
    property var events: []

    width: 16
    height: 16
    visible: true

    TimerDaemon {
        id: daemon

        pluginService: QtObject {
            function isPluginLoaded(id) {
                return win.present;
            }
            function setGlobalVar(id, key, value) {
                win.globalCalls++;
                win.events.push({
                    "id": id,
                    "key": key,
                    "value": value
                });
            }
            function loadPluginData(id, key, fallback) {
                if (id !== "smartTimer")
                    win.alexReads++;
                return fallback;
            }
            function savePluginData(id, key, value) {
            }
            function loadPluginState(id, key, fallback) {
                return fallback;
            }
            function savePluginState(id, key, value) {
            }
        }
    }

    function check(ok, what) {
        if (!ok) {
            console.warn("FAIL " + what);
            Qt.exit(1);
        }
    }

    // Started after the daemon finished loading, so its first read is done
    Timer {
        interval: 100
        running: true
        onTriggered: {
            // Two timers ending in the same tick
            daemon.start(1000, "pasta", "duration", 0, false);
            daemon.start(1000, "tea", "duration", 0, false);
            done.start();
        }
    }

    Timer {
        id: done

        interval: 4000
        onTriggered: {
            check(win.alexReads === 0, "Sands never reads Alex data");
            if (win.present) {
                check(win.globalCalls === 2, "one setGlobalVar per ended timer, got " + win.globalCalls);
                const e = win.events[0];
                check(e.key === "timerFinished", "event key");
                check(Object.keys(e.value).join() === "id,label,endAt", "whitelisted shape");
                check(win.events[0].value.id !== win.events[1].value.id, "ids differ");
            } else {
                check(win.globalCalls === 0, "Alex absent: no call, got " + win.globalCalls);
            }
            console.warn("OK " + (win.present ? "present" : "absent"));
            Qt.exit(0);
        }
    }
}
