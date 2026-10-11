import QtQuick
import QtTest
import qs.Common
import "../../components/favourites"
import "../../components/journal/Paths.js" as Paths

// Pinned favourites with real clicks and keys, both looks, every state: nothing
// shown yet, one, two, three, a very long name, narrow (280 px), Reduce motion,
// a refused start and a name made of markup. A click starts the timer
// again with the same name and duration; no tile leaves the 340 px panel or
// overlaps its neighbour. Run: tests/qml-page/run.sh
Item {
    id: root
    width: 340
    height: 400

    // Stand-in daemon: serves a made-up history and records the starts
    QtObject {
        id: fakeDaemon
        property var data: []
        property var started: []
        property bool refuse: false
        property int reads: 0
        function historyFavourites(done) {
            reads++;
            done(data);
        }
        function start(ms, label, kind) {
            if (refuse)
                return -1;
            started = started.concat([
                {
                    ms: ms,
                    label: label,
                    kind: kind
                }
            ]);
            return started.length;
        }
    }

    Favourites {
        id: fav
        daemon: fakeDaemon
        shown: false
    }

    TestCase {
        name: "Favourites"
        when: windowShown

        readonly property var h: [
            {
                name: "work",
                count: 41,
                ms: 25 * 60000
            },
            {
                name: "tea",
                count: 23,
                ms: 4 * 60000
            },
            {
                name: "pasta",
                count: 17,
                ms: 11 * 60000
            }
        ]
        readonly property var longName: [
            {
                name: "a very long name that cannot possibly fit in one tile",
                count: 5,
                ms: 90 * 60000
            }
        ]

        function open(data, look) {
            fakeDaemon.data = data;
            fakeDaemon.started = [];
            fakeDaemon.refuse = false;
            root.width = 340;
            fav.lookKey = look;
            fav.shown = false;
            fav.shown = true;
            wait(50);
        }

        function tiles() {
            // Every button-like item under the favourites, whichever look is loaded
            const out = [];
            const walk = it => {
                for (const c of it.children) {
                    if (c.Accessible.role === Accessible.Button)
                        out.push(c);
                    else
                        walk(c);
                }
            };
            walk(fav);
            return out;
        }

        function checkLayout(list) {
            for (let i = 0; i < list.length; i++) {
                const p = list[i].mapToItem(fav, 0, 0);
                verify(p.x >= 0 && p.x + list[i].width <= root.width, "tile " + i + " inside the panel");
                verify(list[i].height >= 44, "target at least 44");
                for (let j = i + 1; j < list.length; j++) {
                    const q = list[j].mapToItem(fav, 0, 0);
                    const apart = p.x + list[i].width <= q.x || q.x + list[j].width <= p.x || p.y + list[i].height <= q.y || q.y + list[j].height <= p.y;
                    verify(apart, "tiles " + i + " and " + j + " do not overlap");
                }
            }
        }

        function test_states_data() {
            return [
                {
                    look: "glasses"
                },
                {
                    look: "rows"
                }
            ];
        }

        function test_states(d) {
            open([], d.look);
            compare(tiles().length, 0, "empty state shows no tile");
            open([
                {
                    name: "tea",
                    count: 1,
                    ms: 240000
                }
            ], d.look);
            compare(tiles().length, 0, "started once is not pinned");
            for (let n = 1; n <= 3; n++) {
                open(h.slice(0, n), d.look);
                compare(tiles().length, n, n + " pinned");
                checkLayout(tiles());
            }
            open(h.concat([
                {
                    name: "fourth",
                    count: 16,
                    ms: 60000
                }
            ]), d.look);
            compare(tiles().length, 3, "never a fourth");
            open(longName, d.look);
            compare(tiles().length, 1);
            checkLayout(tiles());
        }

        function test_click_data() {
            return [
                {
                    look: "glasses"
                },
                {
                    look: "rows"
                }
            ];
        }

        function test_click(d) {
            open(h, d.look);
            const t = tiles();
            mouseClick(t[1]);
            compare(fakeDaemon.started.length, 1, "one click starts one timer");
            compare(fakeDaemon.started[0].label, "tea");
            compare(fakeDaemon.started[0].ms, 240000);
            mouseClick(t[1]);
            compare(fakeDaemon.started.length, 1, "a second click on the same tile does nothing");
        }

        function test_keyboard_data() {
            return [
                {
                    look: "glasses"
                },
                {
                    look: "rows"
                }
            ];
        }

        function test_keyboard(d) {
            open(h, d.look);
            const t = tiles();
            t[2].forceActiveFocus();
            keyClick(Qt.Key_Return);
            compare(fakeDaemon.started.length, 1, "Enter starts the focused one");
            compare(fakeDaemon.started[0].label, "pasta");
        }

        function test_reads_only_at_opening() {
            fakeDaemon.data = h;
            fav.shown = false;
            fakeDaemon.reads = 0;
            wait(50);
            compare(fakeDaemon.reads, 0, "nothing read while closed");
            fav.shown = true;
            compare(fakeDaemon.reads, 1, "one read per opening");
            compare(fav.pins.length, 3);
            wait(100);
            compare(fakeDaemon.reads, 1, "nothing more while it stays open");
        }

        function test_refused_start_says_nothing() {
            open(h, "glasses");
            fakeDaemon.refuse = true;
            mouseClick(tiles()[0]);
            compare(fav.startedIndex, -1, "a refused start is not shown as started");
            fakeDaemon.refuse = false;
            mouseClick(tiles()[0]);
            compare(fav.startedIndex, 0);
        }

        function test_markup_name_is_text_data() {
            return [
                {
                    look: "glasses"
                },
                {
                    look: "rows"
                }
            ];
        }

        function test_markup_name_is_text(d) {
            open([
                {
                    name: "<b>x</b><img src='file:///dev/null'>",
                    count: 3,
                    ms: 60000
                }
            ], d.look);
            const find = (it, out) => {
                for (const c of it.children) {
                    if (c.text !== undefined && c.textFormat !== undefined && c.text.indexOf("<b>") >= 0)
                        out.push(c);
                    find(c, out);
                }
                return out;
            };
            const texts = find(fav, []);
            verify(texts.length > 0, d.look + " draws the name");
            for (const t of texts)
                compare(t.textFormat, Text.PlainText, d.look + " name is plain text");
        }

        function test_narrow_data() {
            return [
                {
                    look: "glasses"
                },
                {
                    look: "rows"
                }
            ];
        }

        function test_narrow(d) {
            root.width = 280;
            fakeDaemon.data = longName.concat(h.slice(0, 2));
            fav.lookKey = d.look;
            fav.shown = false;
            fav.shown = true;
            wait(50);
            compare(tiles().length, 3);
            checkLayout(tiles());
        }

        function test_reduce_motion_and_single_flip() {
            open(h, "glasses");
            const glass = t => {
                const walk = it => {
                    for (const c of it.children) {
                        if (c.path === Paths.glass)
                            return c;
                        const r = walk(c);
                        if (r)
                            return r;
                    }
                    return null;
                };
                return walk(t);
            };
            // Normal motion: the glass turns once and rests
            mouseClick(tiles()[0]);
            wait(450);
            compare(glass(tiles()[0]).rotation, 180, "turned over once");
            wait(400);
            compare(glass(tiles()[0]).rotation, 180, "then it rests");
            SettingsData.reduceMotion = true;
            open(h, "glasses");
            mouseClick(tiles()[0]);
            wait(100);
            compare(glass(tiles()[0]).rotation, 0, "Reduce motion: no rotation");
            compare(fav.startedIndex, 0, "the text still changes");
            // No press scale either
            mousePress(tiles()[0]);
            compare(tiles()[0].scale, 1, "Reduce motion: no press scale");
            mouseRelease(tiles()[0]);
            SettingsData.reduceMotion = false;
        }
    }
}
