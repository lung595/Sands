pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import qs.Common
import qs.Services
import "../../components/launcher"

// The cards of the Timers row of Spotlight with real clicks and keys:
// collapsed, open (variant A), ringing (stop, open, snooze), favourite,
// "+N", "Stopped · Undo" (and its toast once the launcher is gone), the
// rename field, the keys DMS hands to an open card, and the motion switch
// (Reduce motion or the setting off: the hourglass clock really stops).
// Run: tests/qml-page/run.sh
Item {
    id: root
    width: 640
    height: 400

    readonly property real t0: 1800000000000
    // DMS's launcher controller, found by the card up its parents (set by
    // the tests that need one)
    property var controller: null

    // DMS's own click under the cards (it runs the item): an open card must
    // never let a click through
    MouseArea {
        id: under
        anchors.fill: parent
        property int hits: 0
        onClicked: hits++
    }

    QtObject {
        id: dmsController
        property string expandedItemId: ""
        property int selectedFlatIndex: -1
        property var sections: []
        property var flatModel: []
        function selectIndex(i) {
            selectedFlatIndex = i;
        }
    }

    // Stand-in daemon: the read API of TimerDaemon and a log of the actions
    QtObject {
        id: fake
        signal timerStarted(int id)
        property real now: root.t0
        property var timers: []
        readonly property var sorted: timers.slice()
        property var calls: []
        property var saved: ({})
        property var settings: ({})
        property string hourglassStyle: "classic"
        readonly property QtObject pluginService: QtObject {
            function savePluginData(id, key, value) {
                fake.saved = Object.assign({}, fake.saved, {
                    [key]: value
                });
            }
        }
        function setting(key, fallback) {
            return key in settings ? settings[key] : fallback;
        }
        function log(name, a, b) {
            calls = calls.concat([b === undefined ? [name, a] : [name, a, b]]);
            return true;
        }
        function find(id) {
            return timers.find(t => t.id === id) || null;
        }
        function remainingOf(t, n) {
            if (!t)
                return 0;
            return t.state === "running" ? t.endAt - n : (t.state === "paused" ? t.remaining : t.finishedAt - n);
        }
        function progressOf(t) {
            return t ? Math.max(0, Math.min(1, remainingOf(t, now) / t.total)) : 0;
        }
        function displayLabel(t) {
            return t ? (t.label || "Timer") : "";
        }
        function colorFor(t) {
            return "#D0BCFF";
        }
        function toggle(id) {
            return log("toggle", id);
        }
        function adjust(id, ms) {
            return log("adjust", id, ms);
        }
        function restart(id) {
            return log("restart", id);
        }
        function remove(id) {
            return log("remove", id);
        }
        function undoRemove(id) {
            return log("undo", id);
        }
        function rename(id, label) {
            return log("rename", id, label);
        }
        function toggleMute(id) {
            return log("mute", id);
        }
    }

    function run(id, left, label) {
        return {
            id: id,
            label: label,
            kind: "duration",
            state: "running",
            endAt: t0 + left,
            total: 900000,
            remaining: 0,
            finishedAt: 0
        };
    }
    function paused(id, left, label) {
        return Object.assign(run(id, 0, label), {
            state: "paused",
            remaining: left
        });
    }
    function ring(id, ago, label) {
        return Object.assign(run(id, 0, label), {
            state: "ringing",
            endAt: t0 - ago,
            finishedAt: t0 - ago
        });
    }
    // The text of a chip that has the focus (any item)
    function textOf(it) {
        return it ? it.text : undefined;
    }
    // The first visible-or-not child whose text is `text`
    function byText(item, text) {
        if (!item)
            return null;
        if (item.text === text && item.clicked !== undefined)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const r = byText(item.children[i], text);
            if (r)
                return r;
        }
        return null;
    }
    function item(data) {
        return {
            id: "live:smartTimer:" + data.id,
            name: data.name,
            data: data
        };
    }
    function timerItem(t, kind) {
        return item({
            id: "timer:" + t.id,
            name: t.label,
            kind: kind || "timer",
            timerId: t.id,
            state: t.state,
            expandable: t.state !== "ringing"
        });
    }

    Component {
        id: cardComponent
        SectionCard {
            width: 600
            height: implicitHeight
            daemon: fake
            lang: "fr"
        }
    }

    TestCase {
        id: tc
        name: "LauncherCard"
        when: windowShown

        property var card: null

        function make(launcherItem, extra) {
            card = createTemporaryObject(cardComponent, root, Object.assign({
                launcherItem: launcherItem
            }, extra));
            verify(card !== null);
            return card;
        }

        function openCard(t) {
            make(root.timerItem(t), {
                expanded: true
            });
            tryCompare(child("expandedLoader"), "status", Loader.Ready);
        }

        function child(name) {
            const c = findChild(card, name);
            verify(c !== null, "no " + name);
            return c;
        }

        function init() {
            root.controller = null;
            under.hits = 0;
            fake.calls = [];
            fake.saved = {};
            fake.settings = {};
            fake.now = root.t0;
            SettingsData.reduceMotion = false;
            ToastService.lastInfo = null;
        }

        function test_collapsedRunning() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            make(root.timerItem(fake.timers[0]));
            compare(child("nameLabel").text + child("timeLabel").text, "Pâtes — 12:34");
            compare(child("line2Icon").name, "alarm");
            verify(/^\d\d:\d\d$/.test(child("line2Text").text), child("line2Text").text);
            compare(card.implicitHeight, 64);
            compare(child("expandedLoader").active, false);
            // The countdown follows the daemon's clock, no refresh needed
            fake.now = root.t0 + 4000;
            compare(child("timeLabel").text, "12:30");
        }

        function test_paused() {
            fake.timers = [root.paused(1, 61000, "Linge")];
            make(root.timerItem(fake.timers[0]));
            compare(child("line2Icon").name, "pause");
            compare(child("line2Text").text, "");
            compare(child("timeLabel").text, "1:01");
            compare(child("smallGlass").glass.paused, true);
        }

        function test_ringingCollapsed() {
            fake.timers = [root.ring(1, 42000, "Pâtes")];
            make(root.timerItem(fake.timers[0]));
            compare(child("timeLabel").text, "+0:42");
            compare(child("timeLabel").color, Theme.error);
            fake.now = root.t0 + 18000;
            compare(child("timeLabel").text, "+1:00", "the overrun grows");
            const stop = child("stopButton");
            verify(stop.visible);
            mouseClick(stop);
            compare(fake.calls, [["remove", 1]], "the stop button stops without opening");
            compare(card.open, false);
            // A click elsewhere on the card opens it (Enter stops: DMS's side)
            mouseClick(card, 60, 30);
            compare(card.open, true);
            tryCompare(child("expandedLoader"), "status", Loader.Ready);
        }

        function test_ringingOpen() {
            fake.timers = [root.ring(1, 42000, "Pâtes")];
            fake.settings = {
                snoozeLast: 10
            };
            make(root.timerItem(fake.timers[0]), {
                expanded: true
            });
            verify(card.implicitHeight > 64);
            verify(child("stopRinging").visible);
            compare(child("pauseButton").visible, false);
            compare(child("closeButton").visible, false);
            const first = child("snooze10");
            verify(first.x < child("snooze1").x, "the last snooze used comes first");
            mouseClick(first);
            compare(fake.calls, [["adjust", 1, 600000]]);
            compare(fake.saved.snoozeLast, 10);
            mouseClick(child("stopRinging"));
            compare(fake.calls[1], ["remove", 1]);
            mouseClick(child("replayButton"));
            compare(fake.calls[2], ["restart", 1]);
        }

        function test_expanded() {
            fake.timers = [root.run(1, 754000, "Pâtes"), root.run(2, 250000, "Thé"), root.paused(3, 1860000, "Linge")];
            openCard(fake.timers[0]);
            compare(child("bigTime").text, "12:34");
            compare(child("othersList").count, 2, "the other timers as mini-cards");
            compare(child("pauseButton").Accessible.name, "Pause");
            mouseClick(child("pauseButton"));
            mouseClick(child("muteButton"));
            mouseClick(child("replayButton"));
            mouseClick(child("closeButton"));
            compare(fake.calls, [["toggle", 1], ["mute", 1], ["restart", 1], ["remove", 1]]);
            // Every control is named for screen readers
            for (const n of ["pauseButton", "replayButton", "closeButton", "muteButton", "collapseButton", "nameBox"])
                verify(child(n).Accessible.name !== "", n);
            fake.timers = [Object.assign({}, fake.timers[0], {
                    muted: true
                })].concat(fake.timers.slice(1));
            compare(child("muteButton").iconName, "music_off");
        }

        function test_otherPicked() {
            fake.timers = [root.run(1, 754000, "Pâtes"), root.run(2, 250000, "Thé")];
            make(root.timerItem(fake.timers[0]), {
                expanded: true
            });
            const list = child("othersList");
            tryVerify(() => list.itemAtIndex(0) !== null);
            mouseClick(list.itemAtIndex(0));
            compare(card.timerId, 2, "the mini-card becomes the open card");
            compare(child("bigTime").text, "4:10");
        }

        function test_favourite() {
            make(root.item({
                id: "favourite:Pâtes",
                name: "Pâtes",
                kind: "favourite",
                ms: 600000
            }));
            compare(child("nameLabel").text, "Pâtes");
            compare(child("line2Text").text, "10m");
            compare(child("stopButton").visible, false);
            compare(child("smallGlass").glass.progress, 1, "a full, still hourglass");
            compare(child("smallGlass").glass.running, false);
        }

        function test_more() {
            fake.timers = [1, 2, 3, 4, 5, 6].map(i => root.run(i, 60000 * i, "T" + i));
            make(root.item({
                id: "more",
                name: "+2",
                kind: "more",
                timerId: 5,
                hidden: 2
            }), {
                expanded: true
            });
            tryCompare(child("expandedLoader"), "status", Loader.Ready);
            compare(child("bigTime").text, "5:00", "+N opens the 5th timer");
            compare(child("othersList").count, 5, "all the others below it");
        }

        function test_stoppedUndo() {
            const at = Date.now();
            make(root.item({
                id: "timer:1",
                name: "Pâtes",
                kind: "stopped",
                timerId: 1,
                state: "stopped",
                at: at
            }));
            const chip = child("undoChip");
            verify(chip.visible);
            compare(chip.Accessible.name, "Annuler");
            mouseClick(chip);
            compare(fake.calls, [["undo", 1]]);
            // The launcher closes within the undo window: a toast with the command
            card.destroy();
            tryVerify(() => ToastService.lastInfo !== null);
            compare(ToastService.lastInfo, ["Pâtes · Arrêté", "", "dms ipc call smartTimer undo"]);
        }

        function test_rename() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            openCard(fake.timers[0]);
            const field = child("nameField");
            mouseClick(child("nameBox"), 5, 10);
            verify(field.visible);
            verify(field.activeFocus, "the field takes the keyboard");
            compare(field.selectedText, "Pâtes");
            // Escape cancels
            keyClick(Qt.Key_Escape);
            compare(field.visible, false);
            compare(fake.calls, []);
            // Emoji only: refused, the field stays
            mouseClick(child("nameBox"), 5, 10);
            field.text = "🍝";
            keyClick(Qt.Key_Return);
            verify(field.visible);
            compare(fake.calls, []);
            // A real name, emoji dropped
            field.text = "Sauce 🍅";
            keyClick(Qt.Key_Return);
            compare(field.visible, false);
            compare(fake.calls, [["rename", 1, "Sauce"]]);
        }

        function test_keys() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            openCard(fake.timers[0]);
            const ev = key => ({
                    key: key,
                    modifiers: Qt.NoModifier,
                    accepted: false
                });
            // From the search field: Space and Escape stay DMS's
            compare(card.handleKey(ev(Qt.Key_Space)), false);
            compare(card.handleKey(ev(Qt.Key_Escape)), false);
            compare(card.handleKey(ev(Qt.Key_Return)), false);
            // F2 renames
            compare(card.handleKey(ev(Qt.Key_F2)), true);
            verify(child("nameField").activeFocus);
            keyClick(Qt.Key_Escape);
            // Tab goes into the controls, then through them
            compare(card.handleKey(ev(Qt.Key_Tab)), true);
            verify(child("nameBox").activeFocus);
            verify(child("nameBox").children.some(c => c.visible && c.border && c.border.width === 2), "the focused name shows the focus ring");
            // In the order they show: name, sound, −1, +1, +5, pause
            for (const n of ["muteButton", "-1", "+1", "+5", "pauseButton"]) {
                keyClick(Qt.Key_Tab);
                const f = root.Window.window.activeFocusItem;
                verify(f && (f.objectName === n || root.textOf(f) === n.replace("-", "−")), n + " has the focus, not " + f);
            }
            // Space on the controls pauses
            keyClick(Qt.Key_Space);
            compare(fake.calls, [["toggle", 1]]);
            // Back to +5, Enter presses it
            keyClick(Qt.Key_Backtab);
            compare(root.textOf(root.Window.window.activeFocusItem), "+5");
            keyClick(Qt.Key_Return);
            compare(fake.calls[1], ["adjust", 1, 300000]);
        }

        function test_flips() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            make(root.timerItem(fake.timers[0]));
            const mini = child("smallGlass");
            compare(mini._flippedAt, 0);
            // The clock running: no flip
            fake.now = root.t0 + 1000;
            compare(mini._flippedAt, 0);
            // +5 min: the time left jumps, it turns over
            fake.timers = [Object.assign({}, fake.timers[0], {
                    endAt: fake.timers[0].endAt + 300000
                })];
            verify(mini._flippedAt > 0, "flipped on +time");
            // A restart signals and jumps: a single turn
            const at = mini._flippedAt;
            fake.timerStarted(1);
            compare(mini._flippedAt, at, "not twice");
            // Reduce motion: no flip at all
            SettingsData.reduceMotion = true;
            mini._flippedAt = 0;
            fake.timers = [Object.assign({}, fake.timers[0], {
                    endAt: fake.timers[0].endAt + 300000
                })];
            fake.timerStarted(1);
            compare(mini._flippedAt, 0);
        }

        function test_motion() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            make(root.timerItem(fake.timers[0]));
            const glass = child("smallGlass").glass;
            verify(card.animate, "the sand flows while the launcher shows");
            const t = glass.fxTime;
            tryVerify(() => glass.fxTime > t, 2000);
            // Reduce motion: everything still, the clock really stopped
            SettingsData.reduceMotion = true;
            compare(card.animate, false);
            compare(glass.animate, false);
            const frozen = glass.fxTime;
            wait(200);
            compare(glass.fxTime, frozen);
            // The Sands setting does the same
            SettingsData.reduceMotion = false;
            card.animateSetting = false;
            compare(glass.animate, false);
            // Nothing moves on a hidden launcher
            card.animateSetting = true;
            verify(glass.animate);
            card.visible = false;
            compare(glass.animate, false);
        }

        function test_ringPulseOnce() {
            fake.timers = [root.ring(1, 1000, "Pâtes")];
            make(root.timerItem(fake.timers[0]));
            const pulse = child("pulse");
            verify(pulse.running, "one soft pulse");
            tryCompare(pulse, "running", false, 3000);
            compare(pulse.loops, 1);
            SettingsData.reduceMotion = true;
            make(root.timerItem(fake.timers[0]));
            compare(child("pulse").running, false, "no pulse with Reduce motion");
        }

        function test_minusUnder61s() {
            fake.timers = [root.run(1, 30000, "Thé")];
            openCard(fake.timers[0]);
            const minus = root.byText(card, "−1");
            verify(minus !== null);
            compare(minus.visible, false, "30 s left: no −1");
            fake.timers = [root.run(1, 45000, "Thé")];
            compare(minus.visible, false, "45 s left: no −1");
            fake.timers = [root.run(1, 62000, "Thé")];
            compare(minus.visible, true, "62 s left: −1");
            fake.timers = [root.run(1, 70000, "Thé")];
            compare(minus.visible, true, "70 s left: −1");
        }

        function test_spaceOnControls() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            openCard(fake.timers[0]);
            // Space pauses whatever control has the focus, it never presses it
            for (const target of ["+5", "replayButton", "closeButton", "muteButton"]) {
                fake.calls = [];
                const it = target === "+5" ? root.byText(card, "+5") : child(target);
                it.forceActiveFocus();
                keyClick(Qt.Key_Space);
                compare(fake.calls, [["toggle", 1]], "Space on " + target);
            }
            // The same when DMS hands the key over with a control focused
            fake.calls = [];
            compare(card.handleKey({
                key: Qt.Key_Space,
                modifiers: Qt.NoModifier
            }), true);
            compare(fake.calls, [["toggle", 1]]);
        }

        function test_spaceNeverStopsRinging() {
            fake.timers = [root.ring(1, 42000, "Pâtes")];
            openCard(fake.timers[0]);
            child("stopRinging").forceActiveFocus();
            keyClick(Qt.Key_Space);
            compare(fake.calls, [], "Space on Stop does nothing");
            keyClick(Qt.Key_Return);
            compare(fake.calls, [["remove", 1]], "Enter on Stop stops");
        }

        function test_openBodyKeepsClicks() {
            fake.timers = [root.ring(1, 42000, "Pâtes")];
            openCard(fake.timers[0]);
            mouseClick(child("bigTime"));
            mouseClick(child("expandedLoader").item.glass);
            mouseClick(card, card.width - 4, card.height - 4);
            mouseClick(card, card.width / 2, 4);
            compare(under.hits, 0, "no click reaches DMS under an open card");
            compare(fake.calls, []);
            // A collapsed card still lets DMS have its clicks
            card.destroy();
            wait(0);
            fake.timers = [root.run(1, 754000, "Pâtes")];
            make(root.timerItem(fake.timers[0]));
            mouseClick(card, 60, 30);
            compare(under.hits, 1);
        }

        function test_selectionFollowsOpenCard() {
            fake.timers = [root.run(1, 754000, "Pâtes"), root.run(2, 250000, "Thé")];
            const a = "live:smartTimer:timer:1", b = "live:smartTimer:timer:2";
            dmsController.sections = [{
                    items: [{
                            id: a
                        }, {
                            id: b
                        }]
                }];
            dmsController.flatModel = [{
                    isHeader: true
                }, {
                    isHeader: false,
                    item: {
                        id: a
                    }
                }, {
                    isHeader: false,
                    item: {
                        id: b
                    }
                }];
            dmsController.selectedFlatIndex = 1;
            dmsController.expandedItemId = a;
            root.controller = dmsController;
            make(root.timerItem(fake.timers[0]), {
                expanded: true,
                selected: true
            });
            const list = child("othersList");
            tryVerify(() => list.itemAtIndex(0) !== null);
            mouseClick(list.itemAtIndex(0));
            compare(dmsController.expandedItemId, b, "B opens");
            compare(dmsController.selectedFlatIndex, 2, "and B gets the selection");
            // A ringing card clicked: it opens and is selected
            fake.timers = [root.run(1, 754000, "Pâtes"), root.ring(2, 1000, "Thé")];
            dmsController.expandedItemId = "";
            dmsController.selectedFlatIndex = 1;
            make(root.timerItem(fake.timers[1]));
            mouseClick(card, 60, 30);
            compare(dmsController.expandedItemId, b);
            compare(dmsController.selectedFlatIndex, 2);
        }

        function test_renameClickElsewhere() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            openCard(fake.timers[0]);
            const field = child("nameField");
            mouseClick(child("nameBox"), 5, 10);
            verify(field.visible);
            // A click inside the field keeps it open
            mouseClick(field, 4, field.height / 2);
            verify(field.visible);
            field.text = "Sauce";
            mouseClick(child("bigTime"));
            compare(field.visible, false, "a click elsewhere validates");
            compare(fake.calls, [["rename", 1, "Sauce"]]);
            // The card closes (a click on another card): the name is kept
            mouseClick(child("nameBox"), 5, 10);
            child("nameField").text = "Sel";
            card.expanded = false;
            tryCompare(child("expandedLoader"), "status", Loader.Null);
            compare(fake.calls[1], ["rename", 1, "Sel"]);
        }

        function test_pickedGone() {
            fake.timers = [1, 2, 3, 4, 5, 6].map(i => root.run(i, 60000 * i, "T" + i));
            make(root.timerItem(fake.timers[0]), {
                expanded: true
            });
            card.openTimer(6);
            compare(card.timerId, 6);
            // Stopped with ×: the card is its own timer again, still open
            fake.timers = fake.timers.slice(0, 5);
            compare(card.timerId, 1);
            tryCompare(card, "pickedId", -1);
            compare(card.open, true);
            tryCompare(child("expandedLoader"), "status", Loader.Ready);
            compare(child("bigTime").text, "1:00");
        }

        function test_noticeDefault() {
            fake.timers = [root.run(1, 754000, "Pâtes")];
            openCard(fake.timers[0]);
            compare(child("noticeBit").icon, "notifications", "unset: the daemon's 2 min notice");
            compare(child("noticeBit").text, "2m");
            fake.settings = {
                noticeMinutes: 0
            };
            openCard(fake.timers[0]);
            compare(child("noticeBit").icon, "notifications_off");
        }
    }
}
