// EndActions.js tests — run with: gjs tests/end-actions.test.js
// Built-in and personal actions, their launcher words, and the guided reason
// when a device action has no Orbit.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const E = load("EndActions.js");

// Built-ins and defaults
let b = E.build([], {});
eq(b.actions.map(a => a.id), ["poweroff", "suspend", "stop-music", "disconnect-device"], "built-in actions");
eq(b.words.poweroff, ["off"], "default word is off");
eq(E.fromWord(b, "off", false), { ok: true, command: ["systemctl", "poweroff"], confirm: true }, "off 30 → power off, confirmed first");
eq(E.resolve(b.actions, "suspend", false).confirm, true, "suspend asks confirmation");
eq(E.resolve(b.actions, "stop-music", false), { ok: true, command: ["playerctl", "--all-players", "stop"], confirm: false }, "stop music needs none");

// Only named words start an action
eq(E.fromWord(b, "reboot", false), { ok: false, reason: "unknown-action" }, "unnamed word refused");
eq(E.fromWord(b, "", false).reason, "unknown-action", "empty word refused");
eq(E.resolve(b.actions, "rm", false).reason, "unknown-action", "unknown id refused");

// Overrides replace the defaults; no sharing between actions
b = E.build([], { poweroff: ["bye", "zzz"], suspend: ["zzz", "dodo"] });
eq(b.words.poweroff, ["bye", "zzz"], "custom words replace the default");
eq(E.fromWord(b, "off", false).reason, "unknown-action", "old default no longer works");
eq(b.words.suspend, ["dodo"], "shared word dropped for the later action");
eq(b.errors, [{ action: "suspend", word: "zzz", reason: "shared" }], "shared reason reported");
b = E.build([], { poweroff: [] });
eq(b.words.poweroff, [], "an empty list clears the words");

// Device action without Orbit → guided message
b = E.build([], { "disconnect-device": ["deco"] });
eq(E.fromWord(b, "deco", false), { ok: false, reason: "needs-orbit" }, "no Orbit → guided reason");
eq(E.fromWord(b, "deco", undefined).reason, "needs-orbit", "unknown Orbit state is no Orbit");
eq(E.fromWord(b, "deco", true).ok, true, "with Orbit it resolves");

// Personal actions: plain data
const good = { name: "Lock screen", words: ["lock"], program: "loginctl", args: ["lock-session"] };
b = E.build([good], {});
eq(b.actions[4], { id: "personal-0", name: "Lock screen", words: ["lock"], program: "loginctl", args: ["lock-session"], confirm: false, needsOrbit: false }, "personal action kept");
eq(E.fromWord(b, "lock", false), { ok: true, command: ["loginctl", "lock-session"], confirm: false }, "personal action resolves to an argument list");
eq(E.build([Object.assign({}, good, { confirm: true })], {}).actions[4].confirm, true, "confirm flag kept");
eq(E.build([Object.assign({}, good, { confirm: "yes" })], {}).actions[4].confirm, false, "only true confirms");
eq(E.build([{ name: "X", program: "/usr/bin/foo" }], {}).actions[4].args, [], "args default to empty");
eq(E.build([good], { "personal-0": ["mine"] }).words["personal-0"], ["mine"], "personal words overridable");

const refused = (p) => E.build([p], {}).errors.map(e => e.reason);
eq(refused(Object.assign({}, good, { name: "" })), ["bad-name"], "empty name");
eq(refused(Object.assign({}, good, { name: "x".repeat(41) })), ["bad-name"], "name too long");
eq(refused(Object.assign({}, good, { name: "a\nb" })), ["bad-name"], "control character in name");
eq(refused(null), ["bad-name"], "null entry");
eq(refused(Object.assign({}, good, { program: "" })), ["bad-program"], "empty program");
eq(refused(Object.assign({}, good, { program: "-rf" })), ["bad-program"], "program looks like an option");
eq(refused(Object.assign({}, good, { program: "ls -l" })), ["bad-program"], "command line in program field");
eq(refused(Object.assign({}, good, { program: "a;b" })), ["bad-program"], "shell metacharacter in program");
eq(refused(Object.assign({}, good, { program: "x".repeat(201) })), ["bad-program"], "program too long");
eq(refused(Object.assign({}, good, { args: "lock" })), ["bad-args"], "args must be a list");
eq(refused(Object.assign({}, good, { args: Array(17).fill("a") })), ["bad-args"], "too many args");
eq(refused(Object.assign({}, good, { args: ["x".repeat(201)] })), ["bad-args"], "arg too long");
eq(refused(Object.assign({}, good, { args: [5] })), ["bad-args"], "arg not a string");
eq(refused(Object.assign({}, good, { args: ["a\u0000b"] })), ["bad-args"], "NUL in arg");
eq(E.build([Object.assign({}, good, { args: ["a b; rm", "--x"] })], {}).actions[4].args, ["a b; rm", "--x"], "args are data, kept verbatim");
b = E.build(Array(17).fill(good), {});
eq(b.actions.length, 4 + 16, "personal actions capped");
eq(b.errors.some(e => e.reason === "too-many-personal"), true, "cap reason");
eq(E.build("junk", null).actions.length, 4, "garbage input");
done();
