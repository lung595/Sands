import QtQuick
import Quickshell
import "AlertPolicy.js" as Policy

// needs: components/alert/AlertPolicy.js
// Offscreen test of the screen choice with the real Quickshell screen list: the
// Variants of the alert windows takes the filtered list, and gets every screen
// when the chosen one is not there. The offscreen screen has no name, so
// "one named screen out of several" is covered by tests/alert-policy.test.js. The windows themselves need a layer
// shell and are not built here. Run with tests/qml/run.sh; any failure prints FAIL.
ShellRoot {
    id: root

    property bool failed: false
    property var names: []
    property int step: 0

    function check(ok, what) {
        if (!ok) {
            failed = true;
            console.warn("FAIL " + what);
        }
    }

    function plugged() {
        const out = [];
        for (let i = 0; i < Quickshell.screens.length; i++)
            out.push(Quickshell.screens[i].name);
        return out;
    }

    // Same model line as DuneWindows and HaloWindows
    Variants {
        id: windows
        model: Policy.pickScreens(Quickshell.screens, root.names)

        QtObject {
            required property var modelData
        }
    }

    Timer {
        id: clock
        interval: 50
        repeat: true
        onTriggered: {
            const all = root.plugged();
            root.step++;
            // The offscreen platform gives one screen without a name: the named
            // paths then fall back to every screen, which is what is checked
            const named = all.length > 0 && all[0] !== "";
            if (root.step === 1) {
                check(all.length >= 1, "the offscreen session has a screen");
                check(windows.instances.length === all.length, "no name: one entry per screen");
                if (named) {
                    check(Policy.screensFor("all", all, "").length === all.length, "all: every screen");
                    check(Policy.screensFor("focused", all, all[0]).length === 1, "focused: one screen");
                } else {
                    check(Policy.screensFor("focused", all, all[0]).length === 0, "a nameless screen cannot be chosen");
                }
                root.names = Policy.screensFor(all[0], all, "");
            } else if (root.step === 2) {
                if (named)
                    check(windows.instances.length === 1 && windows.instances[0].modelData.name === all[0], "named: the entry of that screen only");
                else
                    check(windows.instances.length === all.length, "nameless screen: every screen, never none");
                root.names = Policy.screensFor("NOT-PLUGGED-9", all, "");
            } else if (root.step === 3) {
                check(windows.instances.length === all.length, "unplugged name: every screen");
                root.names = ["NOT-PLUGGED-9"];
            } else if (root.step === 4) {
                check(windows.instances.length === all.length, "names taken before an unplug: every screen, never none");
                check(windows.instances[0].modelData === Quickshell.screens[0], "the entry is the real screen object");
                const rows = Policy.screenChoices(Quickshell.screens, "all");
                check(rows.length === 2 + (named ? all.length : 0), "one row per named screen: " + JSON.stringify(rows));
                clock.stop();
                console.warn(failed ? "FAIL" : "qml PASS");
                Qt.exit(failed ? 1 : 0);
            }
        }
    }

    Component.onCompleted: clock.start()
}
