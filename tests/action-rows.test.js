// ActionRows.js tests - run with: gjs tests/action-rows.test.js
// The settings rows of the end actions: what they show and what each edit does.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const A = load("components/settings/ActionRows.js");

// Rows: three natives, no device action, then the user's commands
let r = A.rows([], {});
eq(r.map(x => x.id), ["poweroff", "suspend", "stop-music"], "natives only, the device action has no row");
eq(r.map(x => x.builtin), [true, true, true], "natives are built in (no Remove)");
eq(r[0].words, ["off"], "Power off keeps its default word");
r = A.rows([{ name: "Backup", program: "backup-photos", args: ["--quick"] }], { "personal-0": ["save"] });
eq(r[3], { id: "personal-0", name: "Backup", builtin: false, icon: "terminal", description: "Runs your command. No question asked.", words: ["save"], command: "backup-photos --quick", index: 0 }, "a command row");
eq(A.rows("junk", 7).length, 3, "damaged storage reads as empty");

// Words: refusals say why, nothing is added
let w = A.addWord([], {}, "suspend", "off");
eq([w.ok, w.reason, w.text], [false, "shared", "“off” already belongs to Power off. Pick another word for this action."], "a taken word names its owner");
eq(A.addWord([], {}, "suspend", "30").reason, "reads-as-number", "number refused");
eq(A.addWord([], {}, "suspend", "min").reason, "reads-as-unit", "unit refused");
eq(A.addWord([], {}, "suspend", "a b").reason, "bad-chars", "space refused");
eq(A.addWord([], {}, "suspend", "").text, "Type a word first.", "empty refused with a sentence");
eq(A.addWord([], {}, "suspend", "x".repeat(30)).reason, "too-long", "long refused");
eq(A.addWord([], {}, "nope", "dodo").reason, "unknown-action", "unknown action refused");
w = A.addWord([], {}, "suspend", "  Dodo ");
eq([w.ok, w.overrides], [true, { suspend: ["dodo"] }], "a word is lower-cased and trimmed");
eq(A.addWord([], w.overrides, "suspend", "dodo").overrides, { suspend: ["dodo"] }, "the same word twice is kept once");
w = A.removeWord([], { suspend: ["dodo"] }, "poweroff", "off");
eq(w.overrides, { suspend: ["dodo"], poweroff: [] }, "removing a default word stores the empty list");
let full = {};
for (let i = 0; i < 8; i++) full = A.addWord([], full, "suspend", "w" + String.fromCharCode(97 + i)).overrides;
eq(A.addWord([], full, "suspend", "more").reason, "too-many-words", "ninth word refused");
eq(A.wordsChanged({}), false, "no change at first");
eq(A.wordsChanged(w.overrides), true, "changed words enable Reset");
eq(A.resetWords(), {}, "reset empties the overrides");

// Commands
eq(A.parseCommand("  backup  --quick "), { program: "backup", args: ["--quick"] }, "split on whitespace");
eq(A.parseCommand(null), { program: "", args: [] }, "null reads as empty");
let c = A.addCommand([], "Backup", "backup-photos --quick");
eq([c.ok, c.personal], [true, [{ name: "Backup", program: "backup-photos", args: ["--quick"] }]], "a command is added");
c = A.addCommand([], "", "backup");
eq([c.ok, c.reason, c.field], [false, "bad-name", "name"], "no name refused beside the name");
c = A.addCommand([], "Backup", "-rf /");
eq([c.reason, c.field], ["bad-program", "command"], "an option as program refused beside the command");
eq(A.addCommand([], "Backup", "").reason, "bad-program", "empty command refused");
eq(A.addCommand([], "Backup", "a\u0000b").reason, "bad-program", "control character refused");
eq(A.addCommand([], "Backup", "x " + "a".repeat(201)).reason, "bad-args", "long argument refused");
let many = [];
for (let i = 0; i < 16; i++) many.push({ name: "c" + i, program: "p", args: [] });
eq(A.addCommand(many, "More", "p").reason, "too-many-personal", "17th command refused");
eq(A.setCommand(many, 3, "Renamed", "q --x").personal[3], { name: "Renamed", program: "q", args: ["--x"] }, "an existing command is replaced");

// Removing renumbers the words of the commands after it
const list = [{ name: "A", program: "a", args: [] }, { name: "B", program: "b", args: [] }, { name: "C", program: "c", args: [] }];
let rm = A.removeCommand(list, { poweroff: ["bye"], "personal-0": ["aa"], "personal-1": ["bb"], "personal-2": ["cc"] }, 1);
eq(rm.personal.map(x => x.name), ["A", "C"], "the command is removed");
eq(rm.overrides, { poweroff: ["bye"], "personal-0": ["aa"], "personal-1": ["cc"] }, "its words go, later ones move up");
done();
