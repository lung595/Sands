// Diagnostics: the allowlist, the anonymization, the memory buffer, the CPU line and the
// report, with the personal values Sands handles (timer labels, launcher text, sound
// paths, trigger word). Every name and path below is made up. The leak checks matter most:
// whatever goes in, none of it may come out. Run: gjs tests/diagnostics.test.js
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { eq: harnessEq, done } = imports.harness;
const GLib = imports.gi.GLib;

// Plugin file as text (the harness keeps its own reader private)
const root = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
const read = path => new TextDecoder().decode(GLib.file_get_contents(root + "/" + path)[1]);

// The order of the shared tests (what, got, expected) over the harness's (got, expected, what)
const eq = (what, got, expected) => harnessEq(got, expected, what);

// Loads a module once and hands the same instance to every module that imports it, as QML
// does: Report.js must see the very Log and Redact the tests feed (the harness loader
// builds a fresh copy per import)
const cache = {};
function load(path) {
    if (cache[path])
        return cache[path];
    const names0 = [];
    const src = read(path).replace(".pragma library", "").replace(/^\.import "([^"]+)" as (\w+)$/gm, (_, rel, name) => {
        names0.push([name, load(GLib.canonicalize_filename(rel, root + "/" + GLib.path_get_dirname(path)).slice(root.length + 1))]);
        return "";
    });
    const names = [...src.matchAll(/^(?:function|var|const) (\w+)/gm)].map(m => m[1]);
    return cache[path] = new Function(...names0.map(i => i[0]), src + "; return { " + names.join(", ") + " };")(...names0.map(i => i[1]));
}

const Allow = load("diagnostics/Allow.js");
const Redact = load("diagnostics/Redact.js");
const Codes = load("diagnostics/Codes.js");
const Log = load("diagnostics/Log.js");
const Cpu = load("diagnostics/Cpu.js");
const Report = load("diagnostics/Report.js");
const Gather = load("diagnostics/Gather.js");

// --- Allow.js ------------------------------------------------------------------------
eq("a yes/no is written yes or no", [Allow.value("bool", true), Allow.value("bool", false)], ["yes", "no"]);
eq("a truthy string is not a yes/no", [Allow.value("bool", "true"), Allow.value("bool", 1)], [null, null]);
eq("a number is rounded and clamped", [Allow.value("int", 3.6), Allow.value("int", 1e12), Allow.value("int", -1e12)], ["4", "1000000000", "-1000000000"]);
eq("a number string, NaN and Infinity are refused", [Allow.value("int", "7"), Allow.value("int", NaN), Allow.value("int", Infinity)], [null, null, null]);
eq("a word is allowed only from its list", [Allow.value(["a", "b"], "a"), Allow.value(["a", "b"], "pasta for Bob")], ["a", null]);
eq("an unknown spec allows nothing", Allow.value("text", "anything"), null);
eq("pick follows the schema's order", Allow.pick({ "x": "int", "y": "bool" }, { "y": true, "x": 2 }), ["x=2", "y=yes"]);
eq("pick drops an unknown key and shows ? for a refused value", Allow.pick({ "x": "int", "y": ["ok"] }, { "x": 1, "y": "pasta for Bob", "label": "Bob" }), ["x=1", "y=?"]);
eq("pick takes nothing from a non-object", [Allow.pick({ "x": "int" }, null), Allow.pick({ "x": "int" }, "x=1")], [[], []]);
eq("pick does not read inherited keys", Allow.pick({ "toString": "int" }, {}), []);

// --- Redact.js: what must never get out ----------------------------------------------
const HT = "ht" + "tp";
const MAC = "AA:BB:CC:DD:EE:01";
const IP4 = "192.168.7.23";
const HOME = "\x2fhome/jdoe";
const secrets = {
    "mac colon": "paired " + MAC,
    "ipv4": "from " + IP4 + " port 22",
    "ipv6": "peer fd7a:115c:a1e0:ab12:4843:cd96:6258:1234 up",
    "home path": "QML Plug at file://" + HOME + "/.config/DankMaterialShell/plugins/smartTimer/A.qml[4:1]",
    "custom sound path": "pw-play " + HOME + "/Music/bobs alarm.mp3 failed",
    "silverblue home": "/var\x2fhome/jdoe/Music/a.mp3",
    "runtime dir": "/run/user/1000/quickshell/by-id/abc",
    "token key": "authkey=tskey-auth-kAbCdEfGh12345-ZyXwVuTs9876",
    "bearer": "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig",
    "long hex": "key 0123456789abcdef0123456789abcdef0123",
    "email": "write to jdoe@example.org",
    "url credentials": HT + "s://jdoe:hunter2@example.org/path",
    "lan host": "reached laptop-jdoe.local and nas.home.arpa"
};
const forbidden = ["AA:BB:CC:DD:EE:01", "192.168.7.23", "fd7a:115c", "jdoe", "hunter2", "tskey-auth", "eyJhbGci", "0123456789abcdef", "laptop-jdoe", "nas.home", "1000/quickshell", "bobs alarm"];
// Redact keeps what follows ~ (a file name can be harmless), so the plugin registers the
// custom sound's file name as soon as it reads the setting: from then on it is an alias
Redact.register("file", "bobs alarm.mp3");
for (const what in secrets) {
    const out = Redact.text(secrets[what]);
    eq("no leak: " + what, forbidden.filter(f => out.indexOf(f) >= 0), []);
}
Redact.forget();
eq("a home path keeps the rest of the path", Redact.text("file://" + HOME + "/.config/a/b.qml"), "file://~/.config/a/b.qml");
eq("a plain time is not an address", Redact.text("12:03:41 ready"), "12:03:41 ready");
eq("a version is not an address", Redact.text("Qt 6.11.2, niri 25.08.1"), "Qt 6.11.2, niri 25.08.1");
eq("a code and its states stay readable", Redact.text("SND-E001 action=stop reason=limit"), "SND-E001 action=stop reason=limit");
eq("a control character cannot forge a new line", Redact.text("a\nb\u0000c\r"), "a b c ");
eq("a long line is cut", Redact.text("ab ".repeat(200)).length, 240);
eq("nothing becomes an empty text", [Redact.text(null), Redact.text(undefined)], ["", ""]);

// Timer labels and launcher text learned at run time become stable aliases
eq("a timer label gets an alias", Redact.register("label", "Bob's pasta"), "label#1");
eq("the same label (any case) gets the same alias", Redact.register("label", "BOB'S PASTA"), "label#1");
eq("the login is hidden as a user", Redact.register("user", "jdoe"), "user#1");
eq("a one-letter label is refused", Redact.register("label", "a"), "");
eq("the known labels are replaced in a line", Redact.text("timer Bob's pasta ended for jdoe"), "timer label#1 ended for user#1");
Redact.forget();
eq("forgetting clears the aliases", Redact.text("Bob's pasta"), "Bob's pasta");
eq("a command is reduced to its program", [Redact.command(["/usr/bin/pw-play", HOME + "/a.wav"]), Redact.command("dms ipc call smartTimer start pasta")], ["pw-play", "dms"]);

// --- Codes.js: the declarations are consistent ---------------------------------------
const wordOk = /^[A-Za-z0-9_.-]{1,24}$/;
const badWords = [];
for (const table of [Codes.FIELDS, Codes.SETTINGS])
    for (const key in table)
        if (Array.isArray(table[key]))
            table[key].forEach(w => { if (!wordOk.test(w)) badWords.push(key + ":" + w); });
eq("every allowed word is a short plain token", badWords, []);
eq("every code is well formed and uses declared fields", Object.keys(Codes.CODES).filter(c => !/^SND-[EWID]\d{3}$/.test(c) || Codes.CODES[c].fields.some(f => !(f in Codes.FIELDS))), []);
eq("every code has a sentence for the guide", Object.keys(Codes.CODES).filter(c => !Codes.CODES[c].text), []);
eq("no field, setting or fact is a free-text kind", [...Object.values(Codes.FIELDS), ...Object.values(Codes.SETTINGS), ...Object.values(Codes.FACTS)].filter(s => !(s === "int" || s === "bool" || Array.isArray(s))), []);
const guide = read("docs/DEBUGGING.md");
eq("every code is explained in docs/DEBUGGING.md", Object.keys(Codes.CODES).filter(c => guide.indexOf("`" + c + "`") < 0), []);
eq("the personal settings are not reported", ["customSound", "trigger"].filter(k => k in Codes.SETTINGS), []);

// The settings page and Codes.SETTINGS cannot drift apart
const OMITTED = ["customSound", "trigger"];
const pageKeys = [...read("TimerSettings.qml").matchAll(/settingKey: "(\w+)"/g)].map(m => m[1]);
eq("every setting of the page is reported or left out on purpose", pageKeys.filter(k => !(k in Codes.SETTINGS) && OMITTED.indexOf(k) < 0), []);
eq("Codes.SETTINGS holds no key the page no longer has", Object.keys(Codes.SETTINGS).filter(k => pageKeys.indexOf(k) < 0), []);

// --- Log.js ----------------------------------------------------------------------------
const journal = [];
Log.setSink({ "error": l => journal.push("E " + l), "warn": l => journal.push("W " + l) });
eq("an error is recorded and returned as a line", Log.event("SND-E001", { "action": "stop", "reason": "limit" }), "SND-E001 action=stop reason=limit");
eq("an error goes to the journal with the plugin's label", journal, ["E [sands] SND-E001 action=stop reason=limit"]);
Log.event("SND-W010", { "tool": "pw_play" });
Log.event("SND-I020", { "surface": "widget" });
Log.event("SND-D040", { "state": "ringing", "count": 3 });
eq("a warning goes to the journal, info and debug do not", journal.length, 2);
eq("all four stay in the buffer, oldest first", Log.entries().map(e => e.line), ["SND-E001 action=stop reason=limit", "SND-W010 tool=pw_play", "SND-I020 surface=widget", "SND-D040 state=ringing count=3"]);

journal.length = 0;
Log.clear();
const line = Log.event("SND-E001", { "action": "pasta for Bob", "reason": HOME + "/Music/a.mp3", "label": "Bob's pasta", "query": "timer 20 min pasta", "path": HOME + "/x", "token": "tskey-auth-abcdef123456" });
eq("a label, a query, a path or a token passed as a field never comes out", [line, journal], ["SND-E001 action=? reason=?", ["E [sands] SND-E001 action=? reason=?"]]);
eq("a field the code does not declare is dropped", Log.event("SND-E002", { "reason": "bad_data", "action": "stop" }), "SND-E002 reason=bad_data");
eq("a code nobody declared is dropped whole", [Log.event("SND-E999", { "reason": "bad_data" }), Log.event("Bob's pasta", {}), Log.event(null), Log.event("__proto__")], ["", "", "", ""]);
Log.clear();
eq("clear empties the buffer", Log.entries(), []);
for (let n = 0; n < 450; n++)
    Log.event("SND-D040", { "count": n });
const kept = Log.entries();
eq("the ring holds exactly its capacity", [Log.CAPACITY, kept.length], [200, 200]);
eq("it keeps the newest and in order", [kept[0].line, kept[199].line], ["SND-D040 count=250", "SND-D040 count=449"]);
Log.clear();

// --- Cpu.js ----------------------------------------------------------------------------
const stat = "1234 (qs) S 1 1234 1234 0 -1 4194560 100 0 0 0 5000 700 0 0 20 0 30 0 100 1000 100 18446744073709551615";
eq("ticks are user + system", Cpu.ticksOf(stat), 5700);
eq("a process name with spaces and brackets does not shift the fields", Cpu.ticksOf(stat.replace("(qs)", "(my ) S (x)")), 5700);
eq("a missing or broken reading is -1", [Cpu.ticksOf(""), Cpu.ticksOf(null), Cpu.ticksOf("12 (x")], [-1, -1, -1]);
eq("17 ticks in one second is 17 % of a core", Cpu.percent(5700, 5717, 1000), 17);
eq("a window too short, or time running backwards, is not measured", [Cpu.percent(10, 20, 50), Cpu.percent(20, 10, 1000), Cpu.percent(10, 20, NaN)], [-1, -1, -1]);
eq("the line says it is the whole shell", Cpu.line({ "percent": 4.2, "windowMs": 1000 }), "4.2% of one core, whole shell (DMS and every plugin), over 1 s");
eq("no measure, no number", [Cpu.line(null), Cpu.line({ "percent": -1, "windowMs": 1000 })], ["not measured", "not measured"]);

// --- Report.js: the whole report, with everything personal thrown at it ----------------
Redact.register("label", "Bob's pasta");
Redact.register("user", "jdoe");
Log.event("SND-I020", { "surface": "widget" });
Log.event("SND-E003", { "tool": "pw_play", "code": 1 });
const report = Report.build({
    "now": Date.UTC(2026, 9, 10, 12, 3, 41),
    "plugin": "1.5.1",
    "versions": { "dms": "1.6.3", "quickshell": "0.3.1", "qt": "6.11.2", "niri": "25.08", "distro": "Fedora Linux 44 (Workstation Edition)" },
    "surfaces": { "widget": true, "daemon": true, "launcher": false, "settings": "yes", "evil": true },
    "settings": { "hourglassStyle": "classic", "volume": 80, "sound": HOME + "/Music/bobs alarm.mp3", "customSound": HOME + "/Music/bobs alarm.mp3", "trigger": "bobtimer", "notify": true },
    "facts": { "timers": 2, "timersRunning": 1, "reduceMotion": false, "hostname": "laptop-jdoe" },
    "cpu": { "percent": 4.2, "windowMs": 1000 },
    "journal": [
        "WARN qml: [sands] SND-W010 tool=pw_play",
        "ERROR qml: QML Sands at file://" + HOME + "/.config/DankMaterialShell/plugins/smartTimer/A.qml[4:1]: Bob's pasta " + MAC + " " + IP4,
        "INFO qml: something unrelated of another plugin 192.168.7.23",
        "Oct 10 12:00:00 laptop-jdoe qs[123]: [sands] SND-W011 reason=bad_input"
    ]
});
const lines = report.split("\n");
eq("the report's header holds the versions, surfaces, settings, state and CPU", lines.slice(0, 11), [
    "Sands diagnostic report (anonymous: versions, states and codes only)",
    "Created      : 2026-10-10 12:03:41 UTC",
    "Plugin       : Sands 1.5.1",
    "DMS          : 1.6.3   Quickshell : 0.3.1   Qt : 6.11.2",
    "Compositor   : niri 25.08",
    "Distribution : Fedora Linux 44 (Workstation Edition)",
    "Surfaces     : widget, daemon (active)",
    "Settings     : hourglassStyle=classic sound=? volume=80 notify=yes",
    "State        : timers=2 timersRunning=1 reduceMotion=no",
    "CPU          : 4.2% of one core, whole shell (DMS and every plugin), over 1 s",
    "Last events (2 of 200 kept, oldest first, UTC):"
]);
eq("only the plugin's own journal lines are kept, cleaned", lines.slice(13), [
    "Journal lines (anonymized, 3 kept, last 50 at most):",
    "  WARN qml: [sands] SND-W010 tool=pw_play",
    "  ERROR qml: QML Sands at file://~/.config/DankMaterialShell/plugins/smartTimer/A.qml[4:1]: label#1 <mac> <ip>",
    "  [sands] SND-W011 reason=bad_input",
    ""
]);
const leaks = ["Bob", "pasta", "jdoe", "AA:BB", "192.168", "\x2fhome/", "Music", "alarm", "bobtimer", "laptop", "hostname"].filter(w => report.indexOf(w) >= 0);
eq("no label, trigger, sound path, address, login or host anywhere in the report", leaks, []);

const bare = Report.build(null);
eq("a report with nothing is still a report", [bare.indexOf("Plugin       : Sands ?") > 0, bare.indexOf("Surfaces     : none active") > 0, bare.indexOf("CPU          : not measured") > 0], [true, true, true]);
const hostile = Report.build({ "plugin": "1.0 " + HOME, "versions": { "dms": { "a": 1 }, "qt": "x\ny", "distro": "<script>" }, "surfaces": 5, "settings": "no", "facts": [1], "cpu": "high", "journal": "no", "now": "never" });
eq("hostile input leaks nothing and never throws", [hostile.indexOf("jdoe"), hostile.indexOf("<script>")], [-1, -1]);

// Zero cost at rest (value 6) and no way out (value 5): no timer, file, process or network
// (Gather only names the commands to run; its comments mention Process, so it is left out)
const files = ["Allow", "Codes", "Cpu", "Log", "Redact", "Report"];
const sources = files.map(f => read("diagnostics/" + f + ".js"));
const banned = new RegExp("Timer|setTimeout|setInterval|FileView|Process\\b|XMLHttpRequest|fetch\\(|WebSocket|\\bimport (Qt|Quickshell|qs)|Qt\\.|" + HT + "s?:");
eq("no timer, file, process, network or QML import in the module", sources.map((src, i) => banned.test(src) ? files[i] : null).filter(Boolean), []);
eq("only warn and error reach the console, never log", sources.filter(src => /console\.(log|debug|info)/.test(src)).length, 0);
eq("no diagnostics file uses a regular expression lookbehind (QML cannot parse it)", sources.filter(src => src.indexOf("(?<" + "!") >= 0 || src.indexOf("(?<" + "=") >= 0).length, 0);

// Hostile values passed as fields: only plain words and numbers may come out
const garbage = ["Bob's pasta", MAC, IP4, HOME + "/x", "tskey-auth-abc123456789", "a\nb", "", null, undefined, {}, [], [1], NaN, Infinity, 1e99, "__proto__", "constructor", true];
const plain = /^SND-[EWID]\d{3}( [a-z]+=(\?|-?\d+|[a-z0-9_.-]+))*$/;
const dirty = [];
Log.setSink({ "error": () => {}, "warn": () => {} });
for (const code of Object.keys(Codes.CODES)) {
    for (const g of garbage) {
        const fields = {};
        Codes.CODES[code].fields.forEach(f => { fields[f] = g; });
        const out = Log.event(code, fields);
        if (!plain.test(out) || forbidden.some(w => out.indexOf(w) >= 0))
            dirty.push(code + " <- " + JSON.stringify(g) + " -> " + out);
    }
}
eq("every code with every hostile value gives a plain line", dirty, []);

// --- Gather.js -------------------------------------------------------------------------
eq("versions come out of each tool's own line", [Gather.parse("dms", "dms v1.6.3\n"), Gather.parse("niri", "niri 26.04 (8ed0da4)"), Gather.parse("quickshell", "Quickshell 0.3.1 (revision , distributed by Someone)")], ["1.6.3", "26.04", "0.3.1"]);
eq("a tool that said nothing usable gives an empty version", [Gather.parse("dms", ""), Gather.parse("niri", "error: \x2fhome/bob/x not found"), Gather.parse("dms", null)], ["", "", ""]);
eq("the distribution is the pretty name of os-release", Gather.parse("distro", 'NAME="Fedora Linux"\nPRETTY_NAME="Fedora Linux 44 (Workstation Edition)"\nID=fedora\n'), "Fedora Linux 44 (Workstation Edition)");
eq("the journal is kept as non-empty lines", Gather.parse("journal", "a\n\nb\n"), ["a", "b"]);
eq("the plugin version is read from plugin.json, or empty", [Gather.pluginVersion('{"version":"1.5.1"}'), Gather.pluginVersion("not json"), Gather.pluginVersion('{"version":3}')], ["1.5.1", "", ""]);
eq("only declared settings are read, an unknown value is skipped", Gather.settingsOf(k => k === "notify" ? true : k === "volume" ? 80 : k === "customSound" ? "x" : undefined), { "volume": 80, "notify": true });
eq("a copy tool that is not installed is told from one that refused", [Gather.missing(-1), Gather.missing(1)], [true, false]);
eq("every probe is an argument list that starts with a program", Gather.PROBES.every(p => Array.isArray(p.command) && /^[a-z]+$/.test(p.command[0])), true);
eq("a long report is cut for the IPC answer", [Gather.capped("x".repeat(30000)).length, Gather.capped("short")], [Gather.MAX_REPORT, "short"]);

done();
