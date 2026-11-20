// Privacy list in the docs — run with: gjs tests/docs-privacy.test.js (from the plugin root)
// README.md and docs/GUIDE.md carry the same "Privacy" list, word for word,
// and its "Tools Sands runs" bullet names every program the code can start:
// the players (Sound.js), the notification (Notifications.js), the report
// probes and copy tools (Gather.js, run through ToolProcess), and every
// literal command array or `sh -c` script of the QML files. A spawn the test
// cannot read fails, so a new one must be listed here and in the docs.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const GLib = imports.gi.GLib;
const { dir, read, load, eq, done } = imports.harness;

// The bullet list right under "## Privacy", up to the first blank line
function privacyList(text) {
    const lines = text.split("\n");
    const start = lines.findIndex(l => l.trim() === "## Privacy");
    if (start < 0)
        return "";
    let i = start + 1;
    while (i < lines.length && lines[i].trim() === "")
        i++;
    const out = [];
    for (; i < lines.length && lines[i].trim() !== ""; i++)
        out.push(lines[i]);
    return out.join("\n");
}

// The programs the "Tools Sands runs" bullet names: each `code` span of the
// bullet and its sub-bullets, first word only (`dms clipboard copy` is dms),
// paths left out
function listedTools(list) {
    const lines = list.split("\n");
    const at = lines.findIndex(l => l.startsWith("- **Tools Sands runs**"));
    if (at < 0)
        return [];
    const block = [lines[at]];
    for (let i = at + 1; i < lines.length && /^\s+- /.test(lines[i]); i++)
        block.push(lines[i]);
    return [...block.join("\n").matchAll(/`([^`]+)`/g)]
        .map(m => m[1].split(" ")[0])
        .filter(w => !/[\/~]/.test(w));
}

// The programs of a shell script: the first word of each command, shell
// built-ins and redirections left out
const BUILTINS = new Set(["umask", "exit", "true", "cd"]);
function scriptTools(script) {
    return script.split(/&&|\|\||;|\|/)
        .map(part => part.trim().split(/\s+/)[0])
        .filter(w => w && !BUILTINS.has(w) && !/^[<>0-9]/.test(w));
}

// The rules themselves
eq(privacyList("# T\n\n## Privacy\n\n- a\n  - b\n- c\n\nMore."), "- a\n  - b\n- c", "the list ends at the blank line");
eq(listedTools("- **Tools Sands runs**:\n  - to ring: `pw-play`;\n  - copy: `dms clipboard copy`, `~/.x`\n- **Other** `nope`"), ["pw-play", "dms"], "tools come from that bullet only");
eq(scriptTools('umask 077 && mkdir -p -- "$1" && cat > "$2.tmp"; rm -f -- "$2" 2>/dev/null; exit 0'), ["mkdir", "cat", "rm"], "a script gives its programs");
eq(scriptTools("find /a -type f \\( -iname '*.ogg' \\) 2>/dev/null | sort"), ["find", "sort"], "a pipe gives both sides");

// The programs the pure modules build: every array returned or kept as a
// command whose first element is a program name
function moduleTools(path) {
    return [...read(path).matchAll(/(?:return|COMMAND\w*\s*=)\s*\[\s*"([\w.-]+)"/g)].map(m => m[1]);
}
const SOUND = moduleTools("components/daemon/Sound.js");
const NOTIFY = moduleTools("components/daemon/Notifications.js");
const Gather = load("diagnostics/Gather.js");
const PROBES = Gather.PROBES.map(p => p.command[0]);
const COPY = Gather.COPY_TOOLS.map(p => p.command[0]);
eq(SOUND.includes("pw-play") && SOUND.includes("paplay"), true, "Sound.js builds pw-play and paplay");
eq(NOTIFY.includes("notify-send") && NOTIFY.includes("gdbus"), true, "Notifications.js builds notify-send and gdbus");
eq(PROBES.length > 0 && COPY.length > 0, true, "Gather.js has probes and copy tools");

// Every QML file of the plugin (tests, previews and renders left out)
function walk(rel, out) {
    const path = dir + "/" + rel;
    if (GLib.file_test(path, GLib.FileTest.IS_DIR)) {
        const d = GLib.Dir.open(path, 0);
        let name;
        while ((name = d.read_name()) !== null)
            if (!(rel === "." && ["tests", "scripts", "out", ".git"].includes(name)))
                walk(rel === "." ? name : rel + "/" + name, out);
        d.close();
    } else if (rel.endsWith(".qml")) {
        out.push(rel);
    }
    return out;
}

// Each place a QML file starts a program, read to the programs it can start;
// an unknown source of command is reported as such
const spawned = new Set();
const unknown = [];
function literal(src) {
    const s = src.trim();
    if (s.startsWith('"'))
        return JSON.parse(s.match(/^"(?:[^"\\]|\\.)*"/)[0]);
    if (s.startsWith("'"))
        return s.match(/^'([^']*)'/)[1];
    return null;
}
for (const f of walk(".", [])) {
    const text = read(f);
    text.split("\n").forEach((line, n) => {
        if (/^\s*\/\//.test(line))
            return;
        const m = line.match(/(?:\bcommand\s*(?::|=(?!=))|execDetached\s*\(|\.launch\s*\()\s*(.*)$/);
        if (!m)
            return;
        const rhs = m[1];
        const where = f + ":" + (n + 1);
        const add = list => list.forEach(t => spawned.add(t));
        if (rhs.startsWith("[")) {
            const first = rhs.match(/^\[\s*"([\w.-]+)"/);
            if (!first)
                return unknown.push(where);
            spawned.add(first[1]);
            if (first[1] !== "sh")
                return;
            const arg = rhs.match(/^\[\s*"sh",\s*"-c",\s*(.*)$/);
            const script = arg && literal(arg[1]);
            if (script !== null && script !== undefined)
                return add(scriptTools(script));
            // HistoryStore: the script is one of its `_scripts`
            if (arg && /^_scripts\[/.test(arg[1].trim())) {
                const block = text.match(/_scripts:\s*\(\{([\s\S]*?)\}\)/);
                if (!block)
                    return unknown.push(where);
                return [...block[1].matchAll(/^\s*\w+:\s*'([^']*)'/gm)].forEach(s => add(scriptTools(s[1])));
            }
            return unknown.push(where);
        }
        if (/^(?:_command\(|Sound\.playerCommand\()/.test(rhs))
            return add(SOUND);
        if (/^Notifications\.(?:showCommand|closeCommand)\(/.test(rhs))
            return add(NOTIFY);
        if (/^Gather\.PROBES\[/.test(rhs))
            return add(PROBES);
        if (/^Gather\.COPY_TOOLS\[/.test(rhs))
            return add(COPY);
        // ToolProcess runs what its callers pass to launch(), read above
        if (f === "components/daemon/ToolProcess.qml" && /^argv;/.test(rhs))
            return;
        // TimerNotifier.tell runs what its callers pass: Notifications.staleCommand
        if (f === "components/daemon/TimerNotifier.qml" && /^command\);/.test(rhs))
            return add(NOTIFY);
        unknown.push(where);
    });
}
eq(unknown, [], "every program start in the QML files is read by this test");
eq(spawned.has("find") && spawned.has("rmdir") && spawned.has("mv"), true, "the sh scripts are read");

// The two docs carry one list
const readme = privacyList(read("README.md"));
const guide = privacyList(read("docs/GUIDE.md"));
eq(readme !== "" && readme === guide, true, "README and GUIDE have the same Privacy list");

const listed = new Set(listedTools(readme));
eq([...spawned].filter(t => !listed.has(t)).sort(), [], "every program Sands starts is in the Privacy list");
// paplay and aplay are the player fallbacks: the list may name them before
// the code starts them (the aplay fallback is being added beside paplay).
// Any other listed name must be a program the code really starts.
const AHEAD = new Set(["paplay", "aplay"]);
eq([...listed].filter(t => !spawned.has(t) && !AHEAD.has(t)).sort(), [], "the Privacy list names only programs Sands starts");

done();
