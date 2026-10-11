.pragma library
.import "../../EndActions.js" as EA
.import "../../LauncherWords.js" as LW

// The end-action rows of the settings page as pure logic: what each row shows
// and the edits the buttons make. Nothing is validated here: every check is
// EndActions.js or LauncherWords.js, this file only turns their reason codes
// into short sentences (value 10: a refusal always says why and what to do).
// Tested by tests/action-rows.test.js.
//
// Stored values (plugin settings):
//   personal   [{ name, program, args }]       the user's own commands
//   overrides  { actionId: [word] }            words changed from the defaults
// A personal action's id is "personal-<position>", so removing one renumbers
// the ones after it and moves their words with them.

var KEY_PERSONAL = "personalActions";
var KEY_WORDS = "actionWords";
// Where the guide explains words and commands
var GUIDE_ANCHOR = "end-actions-and-their-words";

var DESCRIPTIONS = {
    "poweroff": "Shuts the machine down. Asks first.",
    "suspend": "Suspends the machine. Asks first.",
    "stop-music": "Pauses what is playing. No question asked."
};
var ICONS = { "poweroff": "power_settings_new", "suspend": "bedtime", "stop-music": "music_off" };
var COMMAND_DESCRIPTION = "Runs your command. No question asked.";
var COMMAND_ICON = "terminal";
var EMPTY_NOTE = "No command of your own yet.";

// One sentence per reason code: what is wrong, then what to do
var REASONS = {
    "empty": "Type a word first.",
    "too-long": "A word has at most 24 characters.",
    "bad-chars": "Use letters, digits, - or _, starting with a letter.",
    "reads-as-number": "That reads as a number. Start the word with a letter.",
    "reads-as-unit": "That reads as a unit of time. Pick another word.",
    "too-many-words": "At most 8 words per action. Remove one first.",
    "too-many-actions": "Too many actions. Remove a command first.",
    "bad-name": "Give it a name of up to 40 characters.",
    "bad-program": "Type a program name or an absolute path, without an option first.",
    "bad-args": "At most 16 arguments of 200 characters each.",
    "too-many-personal": "At most 16 commands. Remove one first.",
    "unknown-action": "That action does not exist any more.",
    "bad-words": "These words could not be read. Reset the words."
};

function _list(personal) {
    return Array.isArray(personal) ? personal : [];
}

function _overrides(overrides) {
    return overrides && typeof overrides === "object" && !Array.isArray(overrides) ? overrides : {};
}

// The sentence for a refusal. `owner` is the name of the action that holds a
// shared word.
function reasonText(reason, word, owner) {
    if (reason === LW.SHARED)
        return "“" + word + "” already belongs to " + owner + ". Pick another word for this action.";
    return REASONS[reason] || "That could not be saved.";
}

// The command line a field shows and edits: program and arguments, space separated
function commandLine(action) {
    return [action.program].concat(action.args).join(" ");
}

// "backup --quick" → { program, args }. Whitespace splits; there is no quoting
// and no expansion, so the text can never be read as a shell line.
function parseCommand(text) {
    var parts = String(text === undefined || text === null ? "" : text).slice(0, 4096).split(/\s+/).filter(function (p) { return p !== ""; });
    return { program: parts.length > 0 ? parts[0] : "", args: parts.slice(1) };
}

// The rows to draw, in order: Power off, Sleep, Stop the music, then the
// user's commands. The device action belongs to Orbit and has no row.
function rows(personal, overrides) {
    var built = EA.build(_list(personal), _overrides(overrides));
    var out = [];
    built.actions.forEach(function (a) {
        if (a.needsOrbit)
            return;
        var own = a.id.indexOf("personal-") === 0;
        out.push({
            id: a.id, name: a.name, builtin: !own,
            icon: own ? COMMAND_ICON : ICONS[a.id],
            description: own ? COMMAND_DESCRIPTION : DESCRIPTIONS[a.id],
            words: a.words, command: own ? commandLine(a) : "",
            // The personal list index, for edits and removal
            index: own ? parseInt(a.id.slice(9), 10) : -1
        });
    });
    return out;
}

// Whether any words differ from the defaults (enables "Reset the words")
function wordsChanged(overrides) {
    return Object.keys(_overrides(overrides)).length > 0;
}

function _nameOf(built, id) {
    var name = "";
    built.actions.forEach(function (a) {
        if (a.id === id)
            name = a.name;
    });
    return name;
}

// Adds one word to an action. Returns { ok, overrides } or
// { ok: false, reason, text } with the sentence to show beside the field.
function addWord(personal, overrides, actionId, raw) {
    var built = EA.build(_list(personal), _overrides(overrides));
    var c = LW.checkWord(raw);
    if (!c.ok)
        return { ok: false, reason: c.reason, text: reasonText(c.reason, "", "") };
    var current = built.words[actionId];
    if (current === undefined)
        return { ok: false, reason: EA.UNKNOWN_ACTION, text: reasonText(EA.UNKNOWN_ACTION, "", "") };
    var owner = LW.actionFor(built.words, c.word);
    if (owner !== "" && owner !== actionId)
        return { ok: false, reason: LW.SHARED, text: reasonText(LW.SHARED, c.word, _nameOf(built, owner)) };
    if (current.indexOf(c.word) >= 0)
        return { ok: true, overrides: _overrides(overrides) };
    if (current.length >= LW.MAX_WORDS_PER_ACTION)
        return { ok: false, reason: LW.TOO_MANY_WORDS, text: reasonText(LW.TOO_MANY_WORDS, "", "") };
    return { ok: true, overrides: _with(_overrides(overrides), actionId, current.concat([c.word])) };
}

function removeWord(personal, overrides, actionId, word) {
    var built = EA.build(_list(personal), _overrides(overrides));
    var current = built.words[actionId] || [];
    return { ok: true, overrides: _with(_overrides(overrides), actionId, current.filter(function (w) { return w !== word; })) };
}

// All words back to their defaults
function resetWords() {
    return {};
}

function _with(overrides, id, words) {
    var out = {};
    Object.keys(overrides).forEach(function (k) { out[k] = overrides[k]; });
    out[id] = words;
    return out;
}

// Appends a command typed as a name and one command line. Returns
// { ok, personal } or { ok: false, reason, text, field } where `field` is
// the input to mark ("name" or "command").
function addCommand(personal, name, line) {
    return setCommand(_list(personal), _list(personal).length, name, line);
}

// Replaces the command at `index` (or appends when it is the list length)
function setCommand(personal, index, name, line) {
    var list = _list(personal);
    if (index >= list.length && list.length >= EA.MAX_PERSONAL)
        return { ok: false, reason: EA.TOO_MANY_PERSONAL, text: reasonText(EA.TOO_MANY_PERSONAL, "", ""), field: "name" };
    var cmd = parseCommand(line);
    var c = EA.checkPersonal({ name: name, program: cmd.program, args: cmd.args }, index);
    if (!c.ok)
        return { ok: false, reason: c.reason, text: reasonText(c.reason, "", ""), field: c.reason === EA.BAD_NAME ? "name" : "command" };
    var out = list.slice();
    out[index] = { name: c.action.name, program: c.action.program, args: c.action.args };
    return { ok: true, personal: out };
}

// Removes a personal command. Its words go with it and the words of the
// commands after it follow their new position. Returns { personal, overrides }.
function removeCommand(personal, overrides, index) {
    var list = _list(personal);
    var ov = _overrides(overrides);
    var outOv = {};
    Object.keys(ov).forEach(function (k) {
        if (k.indexOf("personal-") !== 0) {
            outOv[k] = ov[k];
            return;
        }
        var n = parseInt(k.slice(9), 10);
        if (n < index)
            outOv[k] = ov[k];
        else if (n > index)
            outOv["personal-" + (n - 1)] = ov[k];
    });
    return { personal: list.filter(function (x, i) { return i !== index; }), overrides: outOv };
}
