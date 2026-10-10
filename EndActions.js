.pragma library
.import "LauncherWords.js" as LW

// End actions: what a timer does when it ends. Only the built-in actions and
// the personal ones named in the settings exist; nothing else can be started
// from the launcher. Commands are always argument lists, never a shell
// string (value 11). Pure logic, no QML, no side effect.
//
// An action is { id, name, words, program, args, confirm, needsOrbit }.

var MAX_PERSONAL = 16;
var MAX_NAME_LENGTH = 40;
var MAX_ARGS = 16;
var MAX_ARG_LENGTH = 200;
var MAX_PROGRAM_LENGTH = 200;

var NEEDS_ORBIT = "needs-orbit";
var UNKNOWN_ACTION = "unknown-action";
var BAD_NAME = "bad-name";
var BAD_PROGRAM = "bad-program";
var BAD_ARGS = "bad-args";
var TOO_MANY_PERSONAL = "too-many-personal";

// Default words are only starting points, never a choice of the user
var BUILTINS = [
    { id: "poweroff", name: "Power off", words: ["off"], program: "systemctl", args: ["poweroff"], confirm: true, needsOrbit: false },
    { id: "suspend", name: "Sleep", words: [], program: "systemctl", args: ["suspend"], confirm: true, needsOrbit: false },
    { id: "stop-music", name: "Stop the music", words: [], program: "playerctl", args: ["--all-players", "stop"], confirm: false, needsOrbit: false },
    // Has no command of its own: only Orbit can act on a device
    { id: "disconnect-device", name: "Disconnect a device", words: [], program: "", args: [], confirm: false, needsOrbit: true }
];

// A program is a bare name or an absolute path, never an option or a path
// with a space-separated command inside
var RE_PROGRAM = /^(?:\/)?[A-Za-z0-9._+\/-]+$/;
// No control character (NUL, newline…) anywhere in a name or argument
var RE_CONTROL = /[\u0000-\u001f\u007f]/;

function validText(s, max) {
    return typeof s === "string" && s.length <= max && !RE_CONTROL.test(s);
}

// Plain data in, { ok, action } or { ok: false, reason } out. The id is
// derived ("personal-<n>") by the caller's position, never typed.
function checkPersonal(raw, index) {
    if (!raw || !validText(raw.name, MAX_NAME_LENGTH) || raw.name.trim() === "")
        return { ok: false, reason: BAD_NAME };
    var p = raw.program;
    if (!validText(p, MAX_PROGRAM_LENGTH) || p === "" || p.charAt(0) === "-" || !RE_PROGRAM.test(p))
        return { ok: false, reason: BAD_PROGRAM };
    var args = raw.args === undefined ? [] : raw.args;
    if (!Array.isArray(args) || args.length > MAX_ARGS)
        return { ok: false, reason: BAD_ARGS };
    for (var i = 0; i < args.length; i++) {
        if (!validText(args[i], MAX_ARG_LENGTH))
            return { ok: false, reason: BAD_ARGS };
    }
    return { ok: true, action: {
        id: "personal-" + index, name: raw.name.trim(), words: Array.isArray(raw.words) ? raw.words : [],
        program: p, args: args.slice(), confirm: raw.confirm === true, needsOrbit: false
    } };
}

// Every usable action: built-ins first, then the valid personal ones.
// `overrides` is { actionId: [words] } from the settings (a missing key keeps
// the defaults). Returns { actions, words, errors } where `words` is the
// validated table and `errors` the refused personal actions and words.
function build(personal, overrides) {
    var errors = [];
    var actions = BUILTINS.map(function (a) { return clone(a); });
    var list = Array.isArray(personal) ? personal : [];
    if (list.length > MAX_PERSONAL) {
        errors.push({ action: "", word: "", reason: TOO_MANY_PERSONAL });
        list = list.slice(0, MAX_PERSONAL);
    }
    list.forEach(function (raw, i) {
        var c = checkPersonal(raw, i);
        if (c.ok)
            actions.push(c.action);
        else
            errors.push({ action: "personal-" + i, word: "", reason: c.reason });
    });
    var ov = overrides && typeof overrides === "object" ? overrides : {};
    actions.forEach(function (a) {
        if (Object.prototype.hasOwnProperty.call(ov, a.id))
            a.words = ov[a.id];
    });
    var checked = LW.checkAll(actions.map(function (a) { return { id: a.id, words: a.words }; }));
    actions.forEach(function (a) { a.words = checked.words[a.id] || []; });
    return { actions: actions, words: checked.words, errors: errors.concat(checked.errors) };
}

function clone(a) {
    return { id: a.id, name: a.name, words: a.words.slice(), program: a.program, args: a.args.slice(), confirm: a.confirm, needsOrbit: a.needsOrbit };
}

// What to do for an action id: { ok, command, confirm } with the argument
// list, or { ok: false, reason }. A device action without Orbit gives the
// guided-message reason, never a silent refusal (value 10).
function resolve(actions, id, orbitAvailable) {
    var a = null;
    (Array.isArray(actions) ? actions : []).forEach(function (x) {
        if (x.id === id)
            a = x;
    });
    if (!a)
        return { ok: false, reason: UNKNOWN_ACTION };
    if (a.needsOrbit && orbitAvailable !== true)
        return { ok: false, reason: NEEDS_ORBIT };
    return { ok: true, command: [a.program].concat(a.args), confirm: a.confirm };
}

// The launcher word → resolved action; refuses any word that names none
function fromWord(built, word, orbitAvailable) {
    var id = LW.actionFor(built.words, word);
    return id === "" ? { ok: false, reason: UNKNOWN_ACTION } : resolve(built.actions, id, orbitAvailable);
}
