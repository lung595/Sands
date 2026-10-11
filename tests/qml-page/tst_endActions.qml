import QtQuick
import QtTest
import "../../scripts/preview/mock"
import "../../components/settings"

// The end-action rows and the erase button with real key events: a refused word
// shows its reason and the guide mark and saves nothing, an accepted word is
// saved without rebuilding the rows, Reset follows the saved words, Erase calls
// the daemon. Run: tests/qml-page/run.sh
Item {
    id: root
    width: 404
    height: 1000

    FakeDaemon {
        id: fake
        week: [
            {
                "name": "x",
                "ms": 1
            }
        ]
    }

    // Stands for the DMS settings host: an in-memory store
    Item {
        id: host
        width: parent.width
        property var saved: ({})
        property int saves: 0
        function loadValue(key, fallback) {
            return key in saved ? saved[key] : fallback;
        }
        function saveValue(key, value) {
            const next = Object.assign({}, saved);
            next[key] = value;
            saved = next;
            saves++;
        }

        EndActionsSection {
            id: section
            daemon: fake
        }
        AdvancedSection {
            id: advanced
            y: 700
            daemon: fake
        }
    }

    TestCase {
        name: "EndActions"
        when: windowShown

        function find(item, pred) {
            for (const c of item.children) {
                if (pred(c))
                    return c;
                const hit = find(c, pred);
                if (hit)
                    return hit;
            }
            return null;
        }
        function wordBox(i) {
            const boxes = [];
            (function walk(it) {
                    for (const c of it.children) {
                        if (c.placeholder === "Add a word")
                            boxes.push(c);
                        walk(c);
                    }
                })(section);
            return boxes[i];
        }
        function typeWord(box, text) {
            box.forceActiveFocus();
            const input = find(box, c => c.hasOwnProperty("maximumLength"));
            input.forceActiveFocus();
            for (const ch of text)
                keyClick(ch);
        }

        function initTestCase() {
            wait(100);
        }

        function test_1_refusedWord() {
            const saves = host.saves;
            const box = wordBox(0);
            typeWord(box, "30");
            keyClick(Qt.Key_Return);
            verify(box.invalid, "the field is marked");
            const err = find(section, c => c.url !== undefined && c.text !== undefined && c.text !== "");
            verify(err, "a reason is shown");
            verify(err.text.length > 0);
            verify(String(err.url).endsWith("#end-actions-and-their-words"), "mark URL: " + err.url);
            compare(host.saves, saves, "nothing saved");
            keyClick(Qt.Key_A);
            verify(!box.invalid, "typing again clears the reason");
        }

        function test_2_acceptedWordKeepsFocus() {
            const box = wordBox(1);
            const other = wordBox(0);
            other.forceActiveFocus();
            typeWord(box, "nap");
            keyClick(Qt.Key_Return);
            verify(!box.invalid);
            verify("nap" in {} || JSON.stringify(host.saved.actionWords).indexOf("nap") >= 0, "saved");
            verify(wordBox(1) === box, "row not rebuilt");
        }

        function test_3_resetFollowsWords() {
            const reset = find(section, c => c.text === "Reset the words");
            verify(reset.enabled, "enabled once a word differs");
            mouseClick(reset);
            verify(!reset.enabled, "disabled again");
        }

        function test_4_erase() {
            const btn = find(advanced, c => c.iconName === "delete");
            verify(btn, "button found");
            mouseClick(btn);
            compare(fake.week.length, 0, "daemon erased");
            verify(advanced.erased);
        }

        function test_5_longTextShowsItsStart() {
            const box = find(section, c => c.placeholder === "Name");
            const probe = box || wordBox(0);
            const input = find(probe, c => c.hasOwnProperty("maximumLength"));
            probe.text = "a-very-long-program-name-that-does-not-fit-in-the-field-at-all-really";
            compare(input.cursorPosition, 0, "start visible after load");
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
            input.focus = false;
            compare(input.cursorPosition, 0, "start visible after focus loss");
            probe.text = "";
        }
    }
}
