import QtQuick
import qs.Common
import qs.Services
import "TimeParser.js" as TP

// Launcher provider. No prefix by default: it only answers when the
// input looks like a duration (« timer 20 min », « 1h30 pâtes », « à 18h »),
// and stays invisible for every other search.
Item {
    id: root

    property var pluginService: null
    property string pluginId: "smartTimer"
    property string trigger: ""

    signal itemsChanged

    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null
    readonly property bool use24h: SettingsData.use24HourClock !== false

    function _usesTrigger() {
        const t = PluginService.getPluginTrigger(pluginId);
        return !!(t && t.trim() !== "");
    }

    function getItems(query) {
        const q = (query || "").trim();
        const withTrigger = _usesTrigger();

        // Trigger alone ("timer"): running timers, or an example.
        if (q === "" || /^(timer|minuteur|minuterie|countdown)$/i.test(q)) {
            if (q === "" && !withTrigger)
                return [];
            return _activeItems();
        }

        const now = Date.now();
        const results = TP.parse(q, now, {
            keyword: withTrigger
        });
        return results.map(r => _startItem(r, now));
    }

    function _startItem(r, now) {
        const end = TP.formatTimeOfDay(r.at || now + r.ms, use24h);
        const tomorrow = TP.isTomorrow(r.at || now + r.ms, now);
        let name, comment;
        if (r.kind === "at") {
            name = (r.label ? r.label + " — " : "Alarm ") + "at " + end + (tomorrow ? " (tomorrow)" : "");
            comment = "Rings in " + TP.formatRelative(r.ms);
        } else {
            name = (r.label ? r.label + " — " : "Timer ") + TP.formatHuman(r.ms);
            comment = "Rings at " + end + (tomorrow ? " tomorrow" : "");
        }
        return {
            name: name,
            icon: r.kind === "at" ? "material:alarm" : "material:timer",
            comment: comment,
            action: "start:" + JSON.stringify({
                ms: r.ms,
                label: r.label,
                kind: r.kind,
                at: r.at || 0
            }),
            categories: ["Minuteur"]
        };
    }

    // Bare "timer": your usual durations (Enter = the first one), then
    // a few classics, then the running timers.
    function _activeItems() {
        const d = daemon;
        const now = Date.now();
        const items = [];
        const seen = {};

        const recents = d ? d.recents.slice(0, 4) : [];
        recents.forEach(r => {
            seen[(r.label || "") + "|" + r.ms] = true;
            const it = _startItem({
                kind: "duration",
                ms: r.ms,
                label: r.label || ""
            }, now);
            it.icon = "material:history";
            items.push(it);
        });

        [5, 10, 25].forEach(mn => {
            if (items.length >= 7 || seen["|" + mn * 60000])
                return;
            items.push(_startItem({
                kind: "duration",
                ms: mn * 60000,
                label: ""
            }, now));
        });

        if (d && d.hasTimers) {
            d.sorted.forEach(t => {
                const state = t.state === "paused" ? "Paused" : (t.state === "ringing" ? "Done" : "Rings at " + TP.formatTimeOfDay(t.endAt, use24h));
                const verb = t.state === "running" ? "Enter: pause" : (t.state === "paused" ? "Enter: resume" : "Enter: stop");
                items.push({
                    name: d.displayLabel(t) + " \u2014 " + TP.formatClock(d.remainingOf(t)),
                    icon: t.state === "ringing" ? "material:alarm" : (t.state === "paused" ? "material:pause_circle" : "material:timelapse"),
                    comment: "Running · " + state + " · " + verb,
                    action: "toggle:" + t.id,
                    categories: ["Minuteur"]
                });
            });
        }
        return items;
    }

    function executeItem(item) {
        if (!item?.action)
            return;
        const sep = item.action.indexOf(":");
        const type = item.action.substring(0, sep);
        const data = item.action.substring(sep + 1);
        const d = daemon;
        if (!d) {
            if (typeof ToastService !== "undefined")
                ToastService.showError("Timer", "The timer service isn't running");
            return;
        }
        switch (type) {
        case "start":
            {
                const p = JSON.parse(data);
                d.start(p.ms, p.label, p.kind, p.at);
                break;
            }
        case "toggle":
            d.toggle(parseInt(data));
            break;
        }
    }

    Component.onCompleted: {
        if (pluginService)
            trigger = PluginService.getPluginTrigger(pluginId) || "";
    }
}
