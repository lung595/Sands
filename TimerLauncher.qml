import QtQuick
import qs.Common
import qs.Services
import "TimeParser.js" as TP
import "L10n.js" as L

// Fournisseur du lanceur. Par défaut sans préfixe : il ne répond que si la
// saisie ressemble à une durée (« timer 20 min », « 1h30 pâtes », « à 18h »),
// et reste invisible pour toutes les autres recherches.
Item {
    id: root

    // Langue de l'interface (réglage du plugin, réactif)
    readonly property string lang: SettingsData.pluginSettings["smartTimer"]?.language || "auto"

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

        // Déclencheur seul (« timer ») : les minuteurs en cours, ou un exemple.
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
            name = (r.label ? r.label + " — " : L.tr(root.lang, "Alarme ")) + L.tr(root.lang, "à ") + end + (tomorrow ? L.tr(root.lang, " (demain)") : "");
            comment = L.tr(root.lang, "Sonne dans ") + TP.formatRelative(r.ms);
        } else {
            name = (r.label ? r.label + " — " : L.tr(root.lang, "Minuteur ")) + TP.formatHuman(r.ms);
            comment = L.tr(root.lang, "Sonne à ") + end + (tomorrow ? L.tr(root.lang, " demain") : "");
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

    // « timer » seul : tes durées habituelles (Entrée = la première), puis
    // quelques classiques, puis les minuteurs en cours.
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
                const state = t.state === "paused" ? L.tr(root.lang, "En pause") : (t.state === "ringing" ? L.tr(root.lang, "Terminé") : L.tr(root.lang, "Sonne à ") + TP.formatTimeOfDay(t.endAt, use24h));
                const verb = t.state === "running" ? L.tr(root.lang, "Entrée : pause") : (t.state === "paused" ? L.tr(root.lang, "Entrée : reprendre") : L.tr(root.lang, "Entrée : arrêter"));
                items.push({
                    name: d.displayLabel(t) + " \u2014 " + TP.formatClock(d.remainingOf(t)),
                    icon: t.state === "ringing" ? "material:alarm" : (t.state === "paused" ? "material:pause_circle" : "material:timelapse"),
                    comment: L.tr(root.lang, "En cours · ") + state + " · " + verb,
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
                ToastService.showError(L.tr(root.lang, "Minuteur"), L.tr(root.lang, "Le module minuteur n'est pas démarré"));
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
