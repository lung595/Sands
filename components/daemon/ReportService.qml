import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../../diagnostics/Cpu.js" as Cpu
import "../../diagnostics/Gather.js" as Gather
import "../../diagnostics/Log.js" as Log
import "../../diagnostics/Redact.js" as Redact
import "../../diagnostics/Report.js" as Report

// Builds the anonymous report (level 2) when somebody asks for it, and does
// nothing otherwise: no timer running, no process, no file open at rest. A
// request reads the shell's CPU ticks, waits one second, reads them again (the
// only way to get a rate), then runs the few short tools of Gather.PROBES one
// after the other and assembles the text with Report.build. The settings
// button and the IPC command share this one component. No step can keep it
// busy for good: a reading that fails counts as "not measured", a tool that
// hangs is stopped after Gather.TOOL_LIMIT_MS.
Item {
    id: root

    // The TimerDaemon: its saved settings and its counts of timers
    required property var engine

    readonly property bool busy: _phase !== "idle"
    // The finished report of an IPC call, kept until takeReport() hands it over
    // (a button press copies its report at once and keeps nothing)
    property string report: ""
    // Where a button press puts its report; the settings row watches its result
    readonly property alias clipboard: copier
    // `via` is "ipc" when the report is kept for the IPC call, else "button"
    signal built(string text, string via)

    // "idle", "before", "waiting", "after", "probing"
    property string _phase: "idle"
    // A button press waits for the report being built
    property bool _copy: false
    // An IPC call waits for it too
    property bool _keep: false
    property real _ticks: -1
    property real _startedAt: 0
    property real _builtAt: 0
    property var _cpu: null
    property var _answers: ({})
    property int _probe: 0
    property string _plugin: ""

    // True when the request is taken: it starts a collection, or joins the one
    // that runs (whoever started it, the button gets that report copied and
    // the IPC call gets it kept). False only for a press during the copy. A
    // report that waits for its IPC call is dropped only by a new IPC request,
    // never by a button press.
    function request(via) {
        const button = via === "button";
        if (button && copier.result === "copying")
            return false;
        if (button) {
            copier.reset();
            _copy = true;
        } else {
            report = "";
            _keep = true;
        }
        if (!busy)
            _start(via);
        return true;
    }

    function _start(via) {
        Log.event("SND-I030", {
            "via": via
        });
        _answers = ({});
        _cpu = null;
        manifest.path = Paths.strip(Qt.resolvedUrl("../../plugin.json"));
        manifest.reload();
        _plugin = Gather.pluginVersion(manifest.text());
        _phase = "before";
        _read();
    }

    // True while an IPC report waits to be taken and is not too old. It only
    // answers: nothing changes.
    function hasReport() {
        return report !== "" && Date.now() - _builtAt <= Gather.REPORT_KEEP_MS;
    }

    // The waiting report, once, or nothing when it is too old (a later call
    // never gets a stale answer); either way it is not kept
    function takeReport() {
        const text = hasReport() ? report : "";
        report = "";
        return text;
    }

    // The path is set on the first request, so nothing is opened before one;
    // setting it loads the file, later requests reload it
    function _read() {
        if (stat.path === "/proc/self/stat")
            stat.reload();
        else
            stat.path = "/proc/self/stat";
    }

    // `ok` is false when the file could not be read: the reading is then -1
    function _loaded(ok) {
        const ticks = ok ? Cpu.ticksOf(stat.text()) : -1;
        if (_phase === "before") {
            _ticks = ticks;
            _startedAt = Date.now();
            _phase = "waiting";
            window.restart();
        } else if (_phase === "after") {
            const ms = Date.now() - _startedAt;
            _cpu = {
                "percent": Cpu.percent(_ticks, ticks, ms),
                "windowMs": ms
            };
            _probe = 0;
            _phase = "probing";
            _next();
        }
    }

    function _next() {
        if (_probe >= Gather.PROBES.length) {
            _finish();
            return;
        }
        probe.launch(Gather.PROBES[_probe].command);
    }

    // The names only this session knows, hidden before any line is cleaned:
    // the custom sound's file name and the login (a line of another program in
    // the journal can hold it outside the home folder)
    function _registerNames() {
        const custom = String(engine.setting("customSound", "") || "");
        Redact.register("sound", custom.slice(custom.lastIndexOf("/") + 1));
        const login = String(Quickshell.env("USER") || "");
        // Shorter, it would hide ordinary words (same floor as diagnose.sh)
        if (login.length >= 3)
            Redact.register("user", login);
    }

    function _finish() {
        _registerNames();
        const timers = engine.timers;
        const a = _answers;
        const text = Report.build({
            "now": Date.now(),
            "plugin": _plugin,
            "versions": {
                "dms": a.dms,
                "quickshell": a.quickshell,
                "qt": a.qt,
                "niri": a.niri,
                "distro": a.distro
            },
            "surfaces": {
                "daemon": true,
                "settings": _copy
            },
            "settings": Gather.settingsOf(key => engine.setting(key, undefined)),
            "facts": {
                "timers": timers.length,
                "timersRunning": timers.filter(t => t.state === "running").length,
                "timersRinging": timers.filter(t => t.state === "ringing").length,
                "reduceMotion": SettingsData.reduceMotion
            },
            "cpu": _cpu,
            "journal": a.journal
        });
        _phase = "idle";
        // The settings button copies it; the IPC command comes back for it
        const via = _keep ? "ipc" : "button";
        if (_copy)
            copier.copy(text);
        if (_keep) {
            report = text;
            _builtAt = Date.now();
        }
        _copy = false;
        _keep = false;
        built(text, via);
    }

    // Opened only for the one read of the request (the path is set there)
    FileView {
        id: stat
        printErrors: false
        onLoaded: root._loaded(true)
        onLoadFailed: root._loaded(false)
    }

    // Read synchronously, once per request
    FileView {
        id: manifest
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: window
        interval: Gather.CPU_WINDOW_MS
        onTriggered: {
            root._phase = "after";
            root._read();
        }
    }

    ToolProcess {
        id: probe
        limitMs: Gather.TOOL_LIMIT_MS
        stdout: StdioCollector {
            id: answer
        }
        // A tool that is not installed (rpm off Fedora, niri under another
        // compositor) or that was stopped for hanging answers nothing: the
        // report says "unknown" for it
        onFinished: code => {
            const spec = Gather.PROBES[root._probe];
            const answers = root._answers;
            answers[spec.key] = Gather.parse(spec.key, code < 0 ? "" : answer.text);
            root._answers = answers;
            root._probe++;
            root._next();
        }
    }

    ReportClipboard {
        id: copier
    }
}
