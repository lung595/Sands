import QtQuick
import QtTest
import "../../scripts/preview/mock"

// Real key events on the settings page: Ctrl+F and / focus the search, typing, Esc and
// Enter work, and a picked row scrolls into view inside a Flickable.
// Run: tests/qml-page/run.sh
Item {
    id: root
    width: 404
    height: 120

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: host.height
        clip: true

        SettingsCase {
            id: host
            pageWidth: 404
        }
    }

    TestCase {
        name: "SettingsKeys"
        when: windowShown

        function find(item, name) {
            for (const c of item.children) {
                if (c.objectName === name)
                    return c;
                const hit = find(c, name);
                if (hit)
                    return hit;
            }
            return null;
        }

        function init() {
            const sp = find(host, "settingsPage");
            sp.query = "";
            sp.forceActiveFocus();
            find(sp, "searchField").focus = false;
            root.forceActiveFocus();
        }

        function test_ctrlF() {
            const field = find(host, "searchField");
            keyClick(Qt.Key_F, Qt.ControlModifier);
            verify(field.activeFocus, "Ctrl+F focuses the field");
        }

        function test_slash() {
            const field = find(host, "searchField");
            keyClick(Qt.Key_Slash);
            verify(field.activeFocus, "/ focuses the field");
            keyClick(Qt.Key_Slash);
            compare(field.text, "/", "/ is typed once the field has the focus");
            field.text = "";
        }

        function test_typeEscEnter() {
            const sp = find(host, "settingsPage");
            const field = find(sp, "searchField");
            keyClick(Qt.Key_F, Qt.ControlModifier);
            keyClick("s");
            keyClick("o");
            keyClick("u");
            keyClick("n");
            keyClick("d");
            compare(sp.query, "sound");
            keyClick(Qt.Key_Escape);
            compare(sp.query, "", "Esc clears the query");
            keyClick("s");
            keyClick("o");
            keyClick("u");
            keyClick("n");
            keyClick("d");
            keyClick(Qt.Key_Return);
            compare(sp.query, "", "Enter clears the query");
            compare(sp.section, "alerts", "Enter opens the first hit");
        }

        function test_revealScrolls() {
            const sp = find(host, "settingsPage");
            flick.contentY = 0;
            sp.open("alerts", "volume");
            wait(100);
            verify(flick.contentY > 0, "the flickable followed the highlighted row");
            const row = sp.flashTarget("volume");
            verify(row, "row found");
            const y = row.mapToItem(flick.contentItem, 0, 0).y;
            verify(y >= flick.contentY && y + row.height <= flick.contentY + flick.height, "row inside the viewport");
        }
    }
}
