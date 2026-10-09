import QtQuick
import "../.."

// Offscreen bench driver for the launcher provider (made-up input only).
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports launcher-loop.qml -- <mode>
//   type   types the bench queries one key at a time at 20 keys/s, forever,
//          calling getItems on every prefix like the launcher does per keystroke
//          (run by banc-ab.sh, which stops it); any other mode sits idle
//   micro  times 2000 getItems calls per full query, prints µs per call, quits
Item {
    readonly property var queries: ["timer 12 min pasta", "14h30 run", "zzzz", "12 min pasta and sauce ".repeat(9).slice(0, 200)]
    readonly property string mode: Qt.application.arguments[Qt.application.arguments.indexOf("--") + 1] || "type"
    property int query: 0
    property int typed: 0

    TimerLauncher {
        id: launcher
    }

    // 50 ms per key: faster than real typing, so the per-keystroke cost is
    // not hidden by idle time between keys.
    Timer {
        running: parent.mode === "type"
        interval: 50
        repeat: true
        onTriggered: {
            const q = parent.queries[parent.query];
            parent.typed++;
            launcher.getItems(q.slice(0, parent.typed));
            if (parent.typed >= q.length) {
                parent.typed = 0;
                parent.query = (parent.query + 1) % parent.queries.length;
            }
        }
    }

    Component.onCompleted: {
        if (mode !== "micro")
            return;
        queries.forEach(q => {
            for (let i = 0; i < 200; i++)
                launcher.getItems(q);
            const n = 2000;
            const t0 = Date.now();
            for (let i = 0; i < n; i++)
                launcher.getItems(q);
            console.warn("micro " + q.length + " chars “" + q.slice(0, 18) + "”: " + ((Date.now() - t0) * 1000 / n).toFixed(1) + " us/call, " + launcher.getItems(q).length + " result(s)");
        });
        Qt.quit();
    }
}
