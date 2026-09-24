import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "TimeParser.js" as TP
import "L10n.js" as L

// Moteur des minuteurs, instancié une seule fois. La barre et le lanceur le
// retrouvent via PluginService.pluginDaemonInstances["smartTimer"].
//
// Un minuteur en marche ne stocke pas un temps restant mais son heure de fin
// (endAt) : rien ne dérive, et un redémarrage de DMS le retrouve pile où il en
// est. Tout changement remplace le tableau `timers` (liaisons QML à jour) et
// est sauvegardé dans l'état du plugin.
Item {
    id: root

    // Langue de l'interface (réglage du plugin, réactif)
    readonly property string lang: SettingsData.pluginSettings["smartTimer"]?.language || "auto"

    property string pluginId: "smartTimer"
    property var pluginService: null

    readonly property string defaultSound: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

    // { id, label, kind: "duration"|"at", total, endAt, remaining,
    //   state: "running"|"paused"|"ringing", finishedAt }
    property var timers: []
    property real now: Date.now()

    // Ordre d'affichage : ce qui sonne, puis ce qui finit le plus tôt, puis
    // les pauses. Ne dépend pas de l'heure (l'ordre des fins ne change pas
    // avec le temps) : recalculé seulement quand la liste change.
    readonly property var sorted: {
        const rank = t => t.state === "ringing" ? 0 : (t.state === "running" ? 1 : 2);
        const key = t => t.state === "running" ? t.endAt : (t.state === "paused" ? t.remaining : t.finishedAt);
        return timers.slice().sort((a, b) => rank(a) - rank(b) || key(a) - key(b));
    }
    readonly property var primary: sorted.length > 0 ? sorted[0] : null
    readonly property int count: timers.length
    readonly property bool hasTimers: timers.length > 0
    readonly property bool ringing: timers.some(t => t.state === "ringing")
    property bool soundActive: false

    // Durées déjà utilisées, les plus fréquentes et récentes en premier :
    // [{ ms, label, uses, last }]. Nourrit « timer » seul dans le lanceur.
    property var recents: []

    // Émis quand un minuteur démarre ou redémarre : la pastille affiche
    // alors brièvement son nom (effet « île dynamique »).
    signal timerStarted(int id)
    // Ouvre/ferme le panneau sur l'écran actif (raccourci clavier, IPC).
    signal panelRequested(string screenName)

    property int _nextId: 1
    property bool _loaded: false

    function setting(key, fallback) {
        return pluginService ? pluginService.loadPluginData(pluginId, key, fallback) : fallback;
    }

    function use24h() {
        return SettingsData.use24HourClock !== false;
    }

    // ------------------------------------------------------------------
    // Lecture
    // ------------------------------------------------------------------

    function remainingOf(t, n) {
        if (!t)
            return 0;
        if (t.state === "running")
            return t.endAt - (n === undefined ? now : n);
        if (t.state === "paused")
            return t.remaining;
        return (t.finishedAt || now) - (n === undefined ? now : n);
    }

    function progressOf(t) {
        if (!t || t.total <= 0)
            return 0;
        return Math.max(0, Math.min(1, remainingOf(t) / t.total));
    }

    function find(id) {
        for (let i = 0; i < timers.length; i++) {
            if (timers[i].id === id)
                return timers[i];
        }
        return null;
    }

    function displayLabel(t) {
        if (!t)
            return "";
        if (t.label)
            return t.label;
        return t.kind === "at" ? L.tr(root.lang, "Alarme") : L.tr(root.lang, "Minuteur");
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------

    function _update(id, fn) {
        let changed = false;
        const list = timers.map(t => {
            if (t.id !== id)
                return t;
            const copy = Object.assign({}, t);
            fn(copy);
            changed = true;
            return copy;
        });
        if (changed)
            _commit(list);
        return changed;
    }

    function _commit(list) {
        timers = list;
        now = Date.now();
        if (pluginService && _loaded) {
            pluginService.savePluginState(pluginId, "timers", list);
            pluginService.savePluginState(pluginId, "nextId", _nextId);
        }
        if (!list.some(t => t.state === "ringing"))
            silence();
        _syncNotifications(list);
        _schedule();
    }

    function _remember(ms, label) {
        const key = (label || "").toLowerCase() + "|" + ms;
        const t0 = Date.now();
        let found = false;
        let list = recents.map(r => {
            if (((r.label || "").toLowerCase() + "|" + r.ms) !== key)
                return r;
            found = true;
            return Object.assign({}, r, {
                uses: (r.uses || 1) + 1,
                last: t0,
                label: label || ""
            });
        });
        if (!found)
            list.push({
                ms: ms,
                label: label || "",
                uses: 1,
                last: t0
            });
        list = _rankRecents(list).slice(0, 12);
        recents = list;
        if (pluginService)
            pluginService.savePluginState(pluginId, "recents", list);
    }

    // « Frécence » : souvent utilisé ET récemment. Un minuteur lancé 10 fois
    // le mois dernier passe après celui d'hier, pas après celui d'il y a un an.
    function _rankRecents(list) {
        const t0 = Date.now();
        const score = r => (r.uses || 1) / (1 + (t0 - (r.last || 0)) / 86400000 / 3);
        return list.slice().sort((a, b) => score(b) - score(a));
    }

    function start(ms, label, kind, at) {
        ms = Math.round(ms);
        if (!(ms >= 1000))
            return -1;
        const t0 = Date.now();
        const id = _nextId++;
        const endAt = kind === "at" && at ? at : t0 + ms;
        _commit(timers.concat([{
            id: id,
            label: (label || "").trim(),
            kind: kind === "at" ? "at" : "duration",
            total: endAt - t0,
            endAt: endAt,
            remaining: endAt - t0,
            state: "running",
            finishedAt: 0,
            hue: _freeHue()
        }]));
        if (kind !== "at")
            _remember(ms, (label || "").trim());
        timerStarted(id);
        return id;
    }

    // Couleur propre à chaque minuteur (sable, anneau, liste) : le premier
    // prend la couleur d'accent, les suivants des teintes voisines. On
    // réutilise la première teinte libre, pour rester stable.
    readonly property int hueCount: 6
    function _freeHue() {
        for (let h = 0; h < hueCount; h++) {
            if (!timers.some(t => t.hue === h))
                return h;
        }
        return timers.length % hueCount;
    }

    function colorFor(t) {
        const base = Theme.primary;
        const idx = t && t.hue !== undefined ? t.hue : 0;
        if (idx === 0)
            return base;
        const shifts = [0, 0.5, 0.17, 0.66, 0.33, 0.83];
        const h = (Math.max(0, base.hslHue) + shifts[idx % shifts.length]) % 1;
        return Qt.hsla(h, Math.max(0.45, base.hslSaturation), Math.min(0.78, Math.max(0.55, base.hslLightness)), 1);
    }

    // Même syntaxe que le lanceur : startText("12 min pâtes").
    function startText(text) {
        const res = TP.parse(text, Date.now(), { keyword: true });
        if (res.length === 0)
            return null;
        const r = res[0];
        start(r.ms, r.label, r.kind, r.at);
        return r;
    }

    function pause(id) {
        const t0 = Date.now();
        return _update(id, t => {
            if (t.state !== "running")
                return;
            t.remaining = Math.max(0, t.endAt - t0);
            t.state = "paused";
        });
    }

    function resume(id) {
        const t0 = Date.now();
        return _update(id, t => {
            if (t.state !== "paused")
                return;
            t.endAt = t0 + t.remaining;
            t.state = "running";
        });
    }

    function toggle(id) {
        const t = find(id);
        if (!t)
            return false;
        if (t.state === "running")
            return pause(id);
        if (t.state === "paused")
            return resume(id);
        return dismiss(id);
    }

    // Ajoute (ou retire) du temps. Sur un minuteur qui sonne : relance pour
    // cette durée (« +1 min » = répéter).
    function adjust(id, deltaMs) {
        const t0 = Date.now();
        return _update(id, t => {
            if (t.state === "ringing") {
                if (deltaMs <= 0)
                    return;
                t.state = "running";
                t.endAt = t0 + deltaMs;
                t.total = deltaMs;
                t.finishedAt = 0;
                t.kind = "duration";
                return;
            }
            const rem = t.state === "running" ? t.endAt - t0 : t.remaining;
            const next = rem + deltaMs;
            if (next < 1000)
                return;
            if (t.state === "running")
                t.endAt += deltaMs;
            else
                t.remaining = next;
            t.total = Math.max(t.total + Math.max(0, deltaMs), next);
        });
    }

    function restart(id) {
        const t0 = Date.now();
        Qt.callLater(() => root.timerStarted(id));
        return _update(id, t => {
            const dur = t.kind === "at" ? Math.max(t.total, 1000) : t.total;
            t.kind = "duration";
            t.total = dur;
            t.endAt = t0 + dur;
            t.remaining = dur;
            t.state = "running";
            t.finishedAt = 0;
        });
    }

    function remove(id) {
        const list = timers.filter(t => t.id !== id);
        if (list.length === timers.length)
            return false;
        _commit(list);
        return true;
    }

    function dismiss(id) {
        return remove(id);
    }

    function dismissRinging() {
        const list = timers.filter(t => t.state !== "ringing");
        if (list.length !== timers.length)
            _commit(list);
        silence();
    }

    function clear() {
        _commit([]);
    }

    // ------------------------------------------------------------------
    // Horloge
    // ------------------------------------------------------------------

    function _tick() {
        const t0 = Date.now();
        now = t0;
        let fired = false;
        const list = timers.map(t => {
            if (t.state !== "running" || t.endAt > t0)
                return t;
            fired = true;
            return Object.assign({}, t, {
                state: "ringing",
                finishedAt: t.endAt,
                remaining: 0
            });
        });
        // Tic-tac discret sur les 10 dernières secondes (option).
        if (!fired && setting("tick", false) && !_muted() && list.some(t => t.state === "running" && t.endAt - t0 > 0 && t.endAt - t0 <= 10050))
            _playTick();
        if (fired) {
            const newly = list.filter(t => t.state === "ringing" && !_notifiers[t.id]);
            _commit(list);
            startRinging();
            newly.forEach(t => _notify(t));
        }
    }

    // ------------------------------------------------------------------
    // Notification de fin, avec actions (utile en plein écran, barre cachée)
    // ------------------------------------------------------------------

    // id du minuteur → { proc, notifId }
    property var _notifiers: ({})

    function _notify(t) {
        if (!setting("notify", true) || _notifiers[t.id])
            return;
        const body = t.kind === "at" ? L.tr(root.lang, "Il est ") + TP.formatTimeOfDay(t.endAt, use24h()) : TP.formatHuman(t.total) + L.tr(root.lang, " écoulées");
        const proc = notifierComp.createObject(root, {
            timerId: t.id,
            command: ["notify-send", "-a", "Sands", "-i", "alarm-symbolic", "-u", "critical", "-p", "-A", "stop=" + L.tr(root.lang, "Arrêter"), "-A", "snooze=+5 min", displayLabel(t) + L.tr(root.lang, " — terminé"), body]
        });
        const map = Object.assign({}, _notifiers);
        map[t.id] = {
            proc: proc,
            notifId: 0
        };
        _notifiers = map;
        proc.running = true;
    }

    // Ferme les notifications des minuteurs qui ne sonnent plus.
    function _syncNotifications(list) {
        for (const key in _notifiers) {
            const id = parseInt(key);
            const t = list.find(x => x.id === id);
            if (t && t.state === "ringing")
                continue;
            const n = _notifiers[key];
            if (n.notifId > 0)
                Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.CloseNotification", String(n.notifId)]);
            const map = Object.assign({}, _notifiers);
            delete map[key];
            _notifiers = map;
        }
    }

    Component {
        id: notifierComp

        Process {
            id: proc
            property int timerId: 0

            stdout: SplitParser {
                onRead: line => {
                    const v = line.trim();
                    const n = root._notifiers[proc.timerId];
                    if (/^\d+$/.test(v)) {
                        if (n)
                            n.notifId = parseInt(v);
                        return;
                    }
                    if (v === "stop")
                        root.dismiss(proc.timerId);
                    else if (v === "snooze")
                        root.adjust(proc.timerId, 300000);
                }
            }

            onExited: {
                const map = Object.assign({}, root._notifiers);
                if (map[proc.timerId] && map[proc.timerId].proc === proc) {
                    delete map[proc.timerId];
                    root._notifiers = map;
                }
                proc.destroy();
            }
        }
    }

    // Réveil calé sur le prochain changement de seconde affichée (≈ 1 fois
    // par seconde), et aucun réveil quand tout est en pause.
    function _schedule() {
        const t0 = Date.now();
        let next = -1;
        for (let i = 0; i < timers.length; i++) {
            const t = timers[i];
            let d = -1;
            if (t.state === "running") {
                const r = t.endAt - t0;
                d = r <= 0 ? 0 : (r % 1000 || 1000);
            } else if (t.state === "ringing") {
                d = 1000 - ((t0 - t.finishedAt) % 1000);
            }
            if (d >= 0 && (next < 0 || d < next))
                next = d;
        }
        if (next < 0) {
            ticker.stop();
            return;
        }
        ticker.interval = Math.max(8, next + 4);
        ticker.restart();
    }

    Timer {
        id: ticker
        repeat: false
        onTriggered: {
            root._tick();
            root._schedule();
        }
    }

    // ------------------------------------------------------------------
    // Son
    // ------------------------------------------------------------------

    property real _ringStartedAt: 0
    property bool _useFallbackPlayer: false

    function soundPath() {
        const choice = setting("sound", "");
        if (choice === "custom") {
            const custom = (setting("customSound", "") || "").trim();
            return custom ? custom.replace(/^file:\/\//, "").replace(/^~(?=\/)/, Quickshell.env("HOME")) : defaultSound;
        }
        return choice || defaultSound;
    }

    function _volume() {
        const v = parseInt(setting("volume", 80));
        return Math.max(0, Math.min(100, isNaN(v) ? 80 : v)) / 100;
    }

    function _command(path, volume) {
        if (_useFallbackPlayer)
            return ["paplay", "--volume=" + Math.round(volume * 65536), path];
        return ["pw-play", "--volume=" + volume.toFixed(2), path];
    }

    // « Ne pas déranger » : la pastille pulse, mais aucun son.
    function _muted() {
        return setting("respectDnd", true) && SessionData.doNotDisturb;
    }

    property int _ringCount: 0

    function startRinging() {
        if (_muted())
            return;
        _ringStartedAt = Date.now();
        _ringCount = 0;
        soundActive = true;
        _playOnce();
    }

    function _playOnce() {
        if (!soundActive)
            return;
        // Sonnerie qui monte : 30 %, 65 %, puis plein volume.
        const ramp = setting("rampUp", true) ? Math.min(1, 0.3 + 0.35 * _ringCount) : 1;
        _ringCount++;
        ringPlayer.command = _command(soundPath(), _volume() * ramp);
        ringPlayer.startedAt = Date.now();
        ringPlayer.running = true;
    }

    // Coupe le son ; le minuteur reste « terminé » (la pastille pulse) tant
    // qu'on ne l'a pas arrêté ou relancé.
    function silence() {
        soundActive = false;
        ringGap.stop();
        if (ringPlayer.running)
            ringPlayer.running = false;
    }

    function previewSound(path) {
        previewPlayer.running = false;
        previewPlayer.command = _command(path || soundPath(), _volume());
        previewPlayer.running = true;
    }

    Process {
        id: ringPlayer
        property real startedAt: 0
        onExited: (exitCode, exitStatus) => {
            if (!root.soundActive)
                return;
            // pw-play absent ou en échec immédiat : on bascule sur paplay.
            if (exitCode !== 0 && !root._useFallbackPlayer && Date.now() - startedAt < 1500) {
                root._useFallbackPlayer = true;
                root._playOnce();
                return;
            }
            const maxMs = Math.max(5, parseInt(root.setting("ringDuration", 60)) || 60) * 1000;
            if (exitCode !== 0 || Date.now() - root._ringStartedAt >= maxMs) {
                root.soundActive = false;
                return;
            }
            ringGap.restart();
        }
    }

    Timer {
        id: ringGap
        interval: 450
        onTriggered: root._playOnce()
    }

    Process {
        id: previewPlayer
    }

    readonly property string tickSound: "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
    function _playTick() {
        tickPlayer.running = false;
        tickPlayer.command = _command(tickSound, _volume() * 0.35);
        tickPlayer.running = true;
    }

    Process {
        id: tickPlayer
    }

    // ------------------------------------------------------------------
    // Persistance et démarrage
    // ------------------------------------------------------------------

    Component.onCompleted: {
        if (!pluginService)
            return;

        // Le lanceur fonctionne sans préfixe par défaut (« 20 min » suffit).
        // Sans ce réglage explicite, DMS retomberait sur le déclencheur « ! ».
        if (pluginService.loadPluginData(pluginId, "noTrigger", null) === null)
            pluginService.savePluginData(pluginId, "noTrigger", true);

        const saved = pluginService.loadPluginState(pluginId, "timers", []);
        _nextId = pluginService.loadPluginState(pluginId, "nextId", 1);
        const t0 = Date.now();
        let ringNow = false;
        const list = (Array.isArray(saved) ? saved : []).filter(t => t && t.id !== undefined).map(t => {
            const copy = Object.assign({}, t);
            if (copy.state === "running" && copy.endAt <= t0) {
                copy.state = "ringing";
                copy.finishedAt = copy.endAt;
                copy.remaining = 0;
                // Fini pendant l'arrêt : on sonne seulement si c'est tout récent.
                if (t0 - copy.endAt < 60000)
                    ringNow = true;
            }
            _nextId = Math.max(_nextId, copy.id + 1);
            return copy;
        });
        recents = _rankRecents(pluginService.loadPluginState(pluginId, "recents", []) || []);
        _loaded = true;
        timers = list;
        now = t0;
        _schedule();
        if (ringNow)
            startRinging();
        list.filter(t => t.state === "ringing" && t0 - t.finishedAt < 60000).forEach(t => _notify(t));
    }

    Component.onDestruction: {
        ticker.stop();
        ringGap.stop();
        ringPlayer.running = false;
        previewPlayer.running = false;
    }

    // ------------------------------------------------------------------
    // IPC : dms ipc call smartTimer <fonction> [arguments]
    // ------------------------------------------------------------------

    IpcHandler {
        target: "smartTimer"

        // dms ipc call smartTimer start "12 min pâtes"
        function start(text: string): string {
            const r = root.startText(text);
            if (!r)
                return L.tr(root.lang, "Durée non reconnue : ") + text;
            return L.tr(root.lang, "Lancé : ") + (r.label || (r.kind === "at" ? L.tr(root.lang, "Alarme") : L.tr(root.lang, "Minuteur"))) + " — " + (r.kind === "at" ? L.tr(root.lang, "à ") + TP.formatTimeOfDay(r.at, root.use24h()) : TP.formatHuman(r.ms));
        }

        // Met en pause / relance le minuteur le plus proche ; arrête la sonnerie.
        function toggle(): string {
            if (root.ringing) {
                root.dismissRinging();
                return L.tr(root.lang, "Sonnerie arrêtée");
            }
            if (!root.primary)
                return L.tr(root.lang, "Aucun minuteur");
            root.toggle(root.primary.id);
            return "OK";
        }

        function pause(): string {
            root.timers.filter(t => t.state === "running").forEach(t => root.pause(t.id));
            return "OK";
        }

        function resume(): string {
            root.timers.filter(t => t.state === "paused").forEach(t => root.resume(t.id));
            return "OK";
        }

        // Arrête ce qui sonne, sinon annule le minuteur le plus proche.
        function stop(): string {
            if (root.ringing) {
                root.dismissRinging();
                return L.tr(root.lang, "Sonnerie arrêtée");
            }
            if (!root.primary)
                return L.tr(root.lang, "Aucun minuteur");
            root.remove(root.primary.id);
            return L.tr(root.lang, "Minuteur annulé");
        }

        // dms ipc call smartTimer add 5  → +5 min au minuteur le plus proche
        function add(minutes: int): string {
            if (!root.primary)
                return L.tr(root.lang, "Aucun minuteur");
            root.adjust(root.primary.id, minutes * 60000);
            return "OK";
        }

        // dms ipc call smartTimer lang fr   (fr, en ou auto)
        function lang(code: string): string {
            if (["fr", "en", "auto"].indexOf(code) < 0)
                return "fr, en, auto";
            root.pluginService?.savePluginData(root.pluginId, "language", code);
            return "OK";
        }

        // À lier à un raccourci : ouvre / ferme le panneau sur l'écran actif.
        function panel(): string {
            const scr = CompositorService.getFocusedScreen();
            root.panelRequested(scr ? scr.name : "");
            return "OK";
        }

        function clear(): string {
            root.clear();
            return L.tr(root.lang, "Tous les minuteurs sont supprimés");
        }

        function list(): string {
            if (root.timers.length === 0)
                return L.tr(root.lang, "Aucun minuteur");
            return root.sorted.map(t => {
                const state = t.state === "paused" ? L.tr(root.lang, " (pause)") : (t.state === "ringing" ? L.tr(root.lang, " (terminé)") : "");
                return root.displayLabel(t) + "\t" + TP.formatClock(root.remainingOf(t)) + state;
            }).join("\n");
        }
    }
}
