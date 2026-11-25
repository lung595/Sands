// Daemon surface test — run with: gjs tests/daemon-surface.test.js (from the plugin root)
// Every member a QML file reads from the daemon (`daemon.X`, `daemon?.X`,
// `engine.X`, or a local alias such as `const d = daemon`) must still be
// declared at the top level of TimerDaemon.qml, so a split cannot silently
// drop one (a missing property reads as undefined, and the view just stops
// reacting). Signal handlers in `Connections { target: daemon }` count too.
// The walk covers every .qml of the plugin, never the preview mocks or tests.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { eq, done, read, listFiles } = imports.harness;

// Reads that are not the TimerDaemon (a local object also named daemon or
// engine, a member of something else), as "file:name.member" -> reason.
// Empty today; every entry must still match a read, so it cannot go stale.
const ALLOWED = {
};

// The source with comments and string contents blanked (newlines kept), so
// a URL, a log line or a commented-out read never counts as a read
function code(src) {
    let out = "", i = 0;
    const blank = s => s.replace(/[^\n]/g, " ");
    while (i < src.length) {
        const c = src[i], n = src[i + 1];
        let end = -1;
        if (c === "/" && n === "/")
            end = src.indexOf("\n", i) < 0 ? src.length : src.indexOf("\n", i);
        else if (c === "/" && n === "*")
            end = src.indexOf("*/", i + 2) < 0 ? src.length : src.indexOf("*/", i + 2) + 2;
        else if (c === '"' || c === "'" || c === "`") {
            end = i + 1;
            while (end < src.length && src[end] !== c && !(c !== "`" && src[end] === "\n"))
                end += src[end] === "\\" ? 2 : 1;
            out += c + blank(src.slice(i + 1, end)) + (end < src.length ? c : "");
            i = end + 1;
            continue;
        }
        if (end < 0) {
            out += c;
            i++;
        } else {
            out += blank(src.slice(i, end));
            i = end;
        }
    }
    return out;
}

const lineOf = (text, index) => text.slice(0, index).split("\n").length;

// Members declared at the top level of TimerDaemon.qml (depth 1: the root
// object's body, not its children's), plus the implicit `xChanged` signals
const daemonSrc = code(read("TimerDaemon.qml"));
const declared = new Set();
const properties = new Set();
let depth = 0;
for (const line of daemonSrc.split("\n")) {
    if (depth === 1) {
        const p = line.match(/^\s*(?:(?:default|required|readonly)\s+)*property\s+\S+\s+(\w+)/);
        const s = line.match(/^\s*(?:signal|function)\s+(\w+)/);
        if (p) {
            declared.add(p[1]);
            properties.add(p[1]);
        } else if (s) {
            declared.add(s[1]);
        }
    }
    for (const ch of line)
        depth += ch === "{" ? 1 : ch === "}" ? -1 : 0;
}
for (const p of properties)
    declared.add(p + "Changed");

eq(["timers", "start", "report", "timerStarted", "ringingChanged"].every(m => declared.has(m)), true, "TimerDaemon.qml top-level members are parsed");
eq(declared.has("interval"), false, "members of TimerDaemon.qml children are not its own");

// Every .qml under the plugin root, preview mocks and tests left out
const qmlFiles = listFiles("", p => p.endsWith(".qml") && p !== "TimerDaemon.qml", (p, n) => n.startsWith(".") || p === "scripts/preview" || p === "tests");

const BASES = ["daemon", "engine"];
const used = new Map();     // "file:name.member" -> line
const reading = new Set();  // files that read the daemon
for (const file of qmlFiles.sort()) {
    const src = code(read(file));
    // Aliases: `property var d: pop.daemon` (read as `d.` or `pop.d.`) and
    // `const d = daemon;` (a bare local)
    const props = [...BASES], locals = [];
    for (const m of src.matchAll(/^\s*(?:(?:readonly|required)\s+)*property\s+var\s+(\w+)\s*:\s*(?:\w+\.)?(?:daemon|engine)\s*(?:\?\?\s*null\s*)?;?\s*$/gm))
        if (!props.includes(m[1]))
            props.push(m[1]);
    for (const m of src.matchAll(/\b(?:const|let|var)\s+(\w+)\s*=\s*(?:\w+\.)?(?:daemon|engine)\s*;/g))
        if (!locals.includes(m[1]))
            locals.push(m[1]);
    const aliases = new Set([...props, ...locals]);

    const alt = locals.length ? "|(?<![\\w.])(" + locals.join("|") + ")" : "";
    for (const m of src.matchAll(new RegExp("(?:\\b(" + props.join("|") + ")" + alt + ")\\s*\\??\\.\\s*(?<member>[A-Za-z_]\\w*)", "g"))) {
        const key = file + ":" + (m[1] || m[2]) + "." + m.groups.member;
        if (!used.has(key))
            used.set(key, lineOf(src, m.index));
        reading.add(file);
    }
    // `Connections { target: root.daemon; function onTimerStarted() {} }`
    for (const m of src.matchAll(/\bConnections\s*\{/g)) {
        let d = 0, end = m.index + m[0].length - 1;
        do
            d += src[end] === "{" ? 1 : src[end] === "}" ? -1 : 0;
        while (d > 0 && ++end < src.length);
        const block = src.slice(m.index, end);
        const target = block.match(/\btarget\s*:\s*(?:\w+\.)?(\w+)\s*$/m);
        if (!target || !(BASES.includes(target[1]) || aliases.has(target[1])))
            continue;
        for (const h of block.matchAll(/\bfunction\s+on([A-Z]\w*)\s*\(/g)) {
            const key = file + ":" + target[1] + "." + h[1][0].toLowerCase() + h[1].slice(1);
            if (!used.has(key))
                used.set(key, lineOf(src, m.index + h.index));
            reading.add(file);
        }
    }
}

eq(reading.size >= 20, true, "the walk finds the QML files that read the daemon (found " + reading.size + ")");
for (const key of Object.keys(ALLOWED))
    eq(used.has(key), true, "allow-list entry '" + key + "' still matches a read");

let missing = 0;
for (const [key, line] of [...used].sort()) {
    const [file, ref] = key.split(":");
    const member = ref.slice(ref.indexOf(".") + 1);
    if (ALLOWED[key] || declared.has(member))
        continue;
    missing++;
    print("✗ " + file + ":" + line + " reads '" + ref + "', not declared by TimerDaemon.qml");
}
eq(missing, 0, used.size + " daemon reads in " + reading.size + " files are declared");
done();
