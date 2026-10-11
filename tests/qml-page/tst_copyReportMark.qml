import QtQuick
import QtTest
import "../../scripts/preview/mock"
import "../../components/settings"

// The GitHub mark beside "Copy report" (D450, D453): the address is the constant
// new-issue page, it opens once per click or key press, never at load, and the
// report text never reaches it.
// Run: tests/qml-page/run.sh
Item {
    id: root
    width: 404
    height: 200

    property var opened: []

    FakeDaemon {
        id: daemon
    }

    CopyReport {
        id: row
        daemon: daemon
        width: 404
        openUrl: url => root.opened.push(url)
    }

    TestCase {
        name: "CopyReportMark"
        when: windowShown

        function marks(item, out) {
            for (const c of item.children) {
                if (c.objectName === "control")
                    out.push(c);
                marks(c, out);
            }
            return out;
        }

        function init() {
            root.opened = [];
            daemon.reportClipboard.result = "idle";
        }

        function test_neverAtLoad() {
            compare(root.opened.length, 0);
        }

        function test_clickOpensConstantUrlOnce() {
            const mark = marks(row, [])[1];
            mouseClick(mark);
            compare(root.opened.length, 1);
            compare(root.opened[0], "https://github.com/lung595/Sands/issues/new/choose");
        }

        function test_keyOpensOnce() {
            const mark = marks(row, [])[1];
            mark.forceActiveFocus();
            keyClick(Qt.Key_Return);
            compare(root.opened.length, 1);
        }

        function test_copyingDoesNotOpenAndUrlHasNoReport() {
            const button = marks(row, [])[0];
            mouseClick(button);
            compare(daemon.reportClipboard.result, "copied");
            compare(root.opened.length, 0);
            mouseClick(marks(row, [])[1]);
            compare(root.opened.length, 1);
            verify(root.opened[0].indexOf("?") < 0 && root.opened[0].indexOf("#") < 0);
        }
    }
}
