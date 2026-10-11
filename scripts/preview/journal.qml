import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/journal"
import "mock"

// Offscreen render of the time journal from made-up weeks.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports journal.qml -- <state> <look> <out.png> [light] [reduce] [narrow]
//   state: empty, one, five, long, many   look: strata, threads
// Also checks the layout: any row wider than the popout or overlapping
// another prints OVERLAP and exits 1.
Window {
    id: win

    readonly property var args: Qt.application.arguments
    readonly property int at: args.indexOf("--")
    readonly property string state: args[at + 1]
    readonly property string look: args[at + 2]
    readonly property string out: args[at + 3]
    readonly property bool reduce: args.indexOf("reduce") >= 0
    readonly property int mm: 60000
    readonly property string longName: "Sourdough second proof with the heavy cast iron pot"
    readonly property var weeks: ({
            "empty": [],
            "one": [["work", 360]],
            "five": [["work", 360], ["reading", 150], ["laundry", 75], ["pasta", 48], ["tea", 12]],
            "long": [["work", 360], [longName, 150], ["laundry", 75], ["pasta", 48], ["Kate — notes", 12]],
            "many": [["work", 360], ["reading", 150], ["laundry", 75], ["pasta", 48], ["tea", 12], ["stretch", 40], ["call", 35], ["nap", 30], ["bread", 25], ["plants", 10], ["eggs", 9], ["rice", 6]]
        })

    width: args.indexOf("narrow") >= 0 ? 260 : 340
    height: 760
    visible: true
    color: Theme.surface

    FakeDaemon {
        id: fake
        week: win.weeks[win.state].map(a => ({
                    "name": a[0],
                    "ms": a[1] * win.mm
                }))
    }

    JournalView {
        id: view
        width: win.width
        daemon: fake
        look: win.look
        reducedMotion: win.reduce
    }

    // Every text and track must stay inside the popout, and no two texts of a
    // row may overlap
    function walk(item, fn) {
        fn(item);
        for (const c of item.children)
            walk(c, fn);
    }
    function check() {
        const boxes = [];
        walk(view, it => {
            if (it.visible && it.text !== undefined && it.text !== "" && it.width > 0)
                boxes.push({
                    "t": it.text,
                    "p": it.mapToItem(view, 0, 0),
                    "w": it.contentWidth !== undefined ? Math.min(it.width, it.contentWidth) : it.width,
                    "h": it.height
                });
        });
        let bad = 0;
        for (const b of boxes)
            if (b.p.x < -0.5 || b.p.x + b.w > win.width + 0.5) {
                console.warn("OVERLAP outside " + b.t);
                bad++;
            }
        for (let i = 0; i < boxes.length; i++)
            for (let j = i + 1; j < boxes.length; j++) {
                const a = boxes[i], b = boxes[j];
                if (a.p.x < b.p.x + b.w - 0.5 && b.p.x < a.p.x + a.w - 0.5 && a.p.y < b.p.y + b.h - 0.5 && b.p.y < a.p.y + a.h - 0.5) {
                    console.warn("OVERLAP " + a.t + " / " + b.t);
                    bad++;
                }
            }
        return bad;
    }

    // Past the last rise (200 ms + 30 ms x 12 names) the picture is final
    Timer {
        interval: 900
        running: true
        onTriggered: {
            const bad = win.check();
            win.contentItem.grabToImage(r => {
                r.saveToFile(win.out);
                Qt.exit(bad > 0 ? 1 : 0);
            });
        }
    }
}
