import QtQuick
import QtTest
import qs.Services
import "../../diagnostics/Log.js" as Log

// The Timers row of Spotlight as TimerLauncher serves it to a DMS with live
// sections: the header, the items, the settings switches, the favourites read
// from the history, and no timer service (one warning, no row). The preview
// PluginService declares requestLauncherUpdate like every DMS: it may only
// fire once DMS has asked for the row. Run: tests/qml-page/run.sh
Item {
    id: root
    width: 400
    height: 200

    // Stand-in daemon: the timers and a made-up history
    QtObject {
        id: fakeDaemon
        property var timers: []
        readonly property int count: timers.length
        readonly property bool hasTimers: timers.length > 0
        property var history: []
        property int reads: 0
        property bool liveSections: false
        property var removed: []
        function historyFavourites(done) {
            reads++;
            done(history);
        }
        function displayLabel(t) {
            return t.label || "Timer";
        }
        function remove(id) {
            removed = removed.concat([id]);
            return true;
        }
    }

    // Stand-in of the injected PluginService: the saved settings
    QtObject {
        id: service
        property var saved: ({})
        function loadPluginData(id, key, fallback) {
            return key in saved ? saved[key] : fallback;
        }
    }

    function run(id, endAt, label) {
        return {
            id: id,
            label: label || "",
            kind: "duration",
            state: "running",
            endAt: endAt,
            total: 60000,
            remaining: 0,
            finishedAt: 0
        };
    }

    function ring(id, label) {
        return {
            id: id,
            label: label || "",
            kind: "duration",
            state: "ringing",
            endAt: 1,
            total: 60000,
            remaining: 0,
            finishedAt: 1
        };
    }

    SignalSpy {
        id: refreshSpy
        target: PluginService
        signalName: "requestLauncherUpdate"
    }

    TestCase {
        name: "LauncherSection"
        when: windowShown

        property var launcher: null

        function init() {
            fakeDaemon.timers = [];
            fakeDaemon.history = [];
            fakeDaemon.removed = [];
            fakeDaemon.reads = 0;
            fakeDaemon.liveSections = false;
            refreshSpy.clear();
            service.saved = {};
            PluginService.pluginDaemonInstances = {
                smartTimer: fakeDaemon
            };
            const c = Qt.createComponent("../../TimerLauncher.qml");
            compare(c.status, Component.Ready, c.errorString());
            launcher = c.createObject(root, {
                pluginService: service
            });
            verify(launcher !== null);
        }

        function cleanup() {
            launcher.destroy();
            launcher = null;
            PluginService.pluginDaemonInstances = {};
        }

        function test_contract() {
            compare(launcher.sectionIcon, "timer");
            compare(launcher.sectionPriority, 1.5);
            verify(launcher.sectionCard !== null);
            verify(["Timers", "Minuteurs"].indexOf(launcher.sectionTitle) >= 0, launcher.sectionTitle);
            compare(launcher.getSectionItems(""), [], "nothing to show: no row");
        }

        function test_timersAndCount() {
            fakeDaemon.timers = [root.run(1, 9000, "Tea"), root.ring(2, "Pasta")];
            const items = launcher.getSectionItems("");
            compare(items.map(i => i.id), ["timer:2", "timer:1"]);
            compare(items[0].preferSelect, true);
            compare(launcher.getSectionItems("fir")[0].preferSelect, false);
            fakeDaemon.timers = [1, 2, 3, 4, 5, 6].map(i => root.run(i, 1000 * i));
            const six = launcher.getSectionItems("");
            compare(six.length, 5);
            compare(six[4].name, "+2");
            verify(/ · 6$/.test(launcher.sectionTitle), launcher.sectionTitle);
        }

        function test_settings() {
            fakeDaemon.timers = [root.run(1, 9000)];
            service.saved = {
                launcherSection: false
            };
            compare(launcher.getSectionItems(""), [], "section off");
            compare(launcher.getSectionItems("timer").length, 1, "a timer command still shows it");
            service.saved = {
                launcherSectionDuringSearch: false
            };
            compare(launcher.getSectionItems("").length, 1);
            compare(launcher.getSectionItems("fir"), [], "hidden while searching");
        }

        function test_favourites() {
            fakeDaemon.history = [
                {
                    name: "Pasta",
                    count: 4,
                    ms: 600000
                },
                {
                    name: "Tea",
                    count: 2,
                    ms: 240000
                }
            ];
            // The favourites are read once the daemon is there, not per query
            tryCompare(fakeDaemon, "reads", 1, 2000);
            const items = launcher.getSectionItems("");
            compare(items.map(i => i.kind), ["favourite", "favourite"]);
            launcher.getSectionItems("p");
            compare(fakeDaemon.reads, 1, "typing reads nothing");
            service.saved = {
                launcherSectionFavourites: false
            };
            compare(launcher.getSectionItems(""), [], "favourites off");
        }

        // An older DMS declares requestLauncherUpdate too and would run its
        // search again: new favourites ask for a refresh only after DMS has
        // asked for the row
        function test_refreshOnlyWithLiveSections() {
            fakeDaemon.history = [
                {
                    name: "Pasta",
                    count: 4,
                    ms: 600000
                }
            ];
            tryCompare(fakeDaemon, "reads", 1, 2000);
            compare(fakeDaemon.liveSections, false);
            compare(refreshSpy.count, 0, "row never asked for: no refresh");
            compare(launcher.getSectionItems("").length, 1);
            compare(fakeDaemon.liveSections, true, "DMS asked for the row");
            fakeDaemon.history = fakeDaemon.history.concat([
                {
                    name: "Tea",
                    count: 2,
                    ms: 240000
                }
            ]);
            fakeDaemon.timersChanged();
            tryCompare(fakeDaemon, "reads", 2, 2000);
            compare(refreshSpy.count, 1, "now one refresh");
            compare(refreshSpy.signalArguments[0][0], "smartTimer");
        }

        function test_stopFromTheRow() {
            fakeDaemon.timers = [root.ring(5, "Pasta")];
            const it = launcher.getSectionItems("")[0];
            compare(it.action, "stop:5");
            launcher.executeItem(it);
            compare(fakeDaemon.removed, [5]);
        }

        function test_noDaemonWarnsOnce() {
            PluginService.pluginDaemonInstances = {};
            const before = Log.entries().filter(e => e.line.indexOf("SND-W012") === 0).length;
            compare(launcher.getSectionItems(""), []);
            compare(launcher.getSectionItems("timer"), []);
            const after = Log.entries().filter(e => e.line.indexOf("SND-W012") === 0).length;
            compare(after - before, 1, "one warning only");
        }

        function test_card() {
            fakeDaemon.timers = [root.ring(2, "Pasta")];
            const raw = launcher.getSectionItems("")[0];
            const card = launcher.sectionCard.createObject(root, {
                launcherItem: {
                    id: "live:smartTimer:" + raw.id,
                    name: raw.name,
                    data: raw
                },
                selected: true
            });
            verify(card !== null);
            compare(card.kind, "timer");
            compare(card.ringing, true);
            verify(card.implicitHeight > 0);
            card.destroy();
        }
    }
}
