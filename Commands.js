.pragma library
.import "TimeParser.js" as TP
.import "Timers.js" as Timers
.import "components/daemon/Lifecycle.js" as Lifecycle
.import "components/daemon/Snooze.js" as Snooze
.import "Strings.js" as Strings

// Launcher commands on the timers that already run, in English and French
// (the words come from the packs of TimeParser.PACKS). Pure: no QML, no
// clock of its own, no side effects. Three steps, for the launcher:
//
//   const intent = parseCommand(text, { lang })        // what was asked, or null
//   const target = resolveTarget(intent, timers, now)  // which timer, or null
//   const shown = previewCommand(intent, target, now, { use24, lang })
//
// An intent is { kind, delta, name, newName, minutes, lang }:
//   kind     "adjust" (« timer +5 », « timer -2 pâtes », « pâtes +1h »),
//            "pause" (« pause pâtes »), "resume" (« reprendre »),
//            "snooze" (« snooze 10 »), "rename" (« renomme pâtes en riz »,
//            « rename tea to infusion », « thé = infusion »)
//   delta    adjust: signed milliseconds
//   name     the timer named, "" = the nearest one (see resolveTarget)
//   newName  rename: the new name, emoji removed
//   minutes  snooze: whole minutes, 0 = the default snooze
//   lang     "fr" or "en" when the verb belongs to one language only, else ""
//
// A command whose target is null does nothing: the launcher then treats the
// text as a new timer (TP.parse), so « pause café 15 min » still starts one.

var ICONS = { adjust: "more_time", pause: "pause", resume: "play_arrow", snooze: "snooze", rename: "edit" };

// The state a timer must be in for each command; adjust and rename take any
var STATES = { pause: "running", resume: "paused", snooze: "ringing" };

// Per pack and for their union: one regex per verb list, anchored at the start
function commandGrammar(packs) {
    var verbs = function (list, key) {
        var all = [];
        for (var i = 0; i < list.length; i++)
            all = all.concat(list[i].COMMANDS[key] || []);
        return new RegExp("^\\s*(?:" + TP.alt(all) + ")(?![a-z])");
    };
    var kinds = ["pause", "resume", "snooze", "rename"];
    var cg = { all: {}, byPack: [], renameTo: null };
    var to = [];
    for (var k = 0; k < kinds.length; k++)
        cg.all[kinds[k]] = verbs(packs, kinds[k]);
    for (var p = 0; p < packs.length; p++) {
        var one = { name: packs[p].NAME, keyword: TP.grammar([packs[p]]).keyword };
        for (k = 0; k < kinds.length; k++)
            one[kinds[k]] = verbs([packs[p]], kinds[k]);
        cg.byPack.push(one);
        to = to.concat(packs[p].COMMANDS.renameTo || []);
    }
    cg.renameTo = new RegExp("(?:^|\\s)(?:" + TP.alt(to) + ")\\s+(?=\\S)");
    return cg;
}

var COMMAND_GRAMMAR = commandGrammar(TP.PACKS);

// The language of the words at the start of `work` for regex key `key`
// ("keyword" or a verb kind): a pack name when only one pack has them, else ""
function langOf(work, key) {
    var found = "";
    for (var i = 0; i < COMMAND_GRAMMAR.byPack.length; i++) {
        var one = COMMAND_GRAMMAR.byPack[i];
        if (one[key].test(work)) {
            if (found)
                return "";
            found = one.name;
        }
    }
    return found;
}

// A name as typed, cleaned: no emoji, no small words or punctuation at the ends
function cleanName(text) {
    return TP.cleanLabel(text, TP.normalize(text)).substring(0, TP.MAX_LABEL).trim();
}

function intent(kind, lang) {
    return { kind: kind, delta: 0, name: "", newName: "", minutes: 0, lang: lang || "" };
}

// « thé = infusion », « renomme pâtes en riz », « rename tea to infusion »
function readRename(original, work, offset, lang) {
    var eqAt = work.indexOf("=", offset);
    var it, name, newName;
    if (eqAt >= 0) {
        name = original.substring(offset, eqAt);
        newName = original.substring(eqAt + 1);
        if (!/[a-z]/.test(TP.normalize(name)) || newName.indexOf("=") >= 0)
            return null;
        it = intent("rename", lang);
    } else {
        var verb = COMMAND_GRAMMAR.all.rename.exec(work.substring(offset));
        if (!verb)
            return null;
        var start = offset + verb[0].length;
        var to = COMMAND_GRAMMAR.renameTo.exec(work.substring(start));
        if (!to)
            return null;
        name = original.substring(start, start + to.index);
        newName = original.substring(start + to.index + to[0].length);
        it = intent("rename", langOf(work.substring(offset), "rename") || lang);
    }
    it.name = cleanName(name);
    it.newName = Timers.stripEmoji(newName, TP.MAX_LABEL);
    return /[^\s\d!-\/:-@\[-`{-~]/.test(TP.normalize(it.newName)) ? it : null;
}

// « +5 », « -2 pâtes », « +1h30 », « pâtes +5 »: the amount is read by
// TP.parse as after « timer », so every duration it knows works here
function readAdjust(original, work, offset, lang, now) {
    var rest = work.substring(offset);
    var m = /^\s*([+-])\s*(?=\d)/.exec(rest);
    var name = "", amountAt;
    if (m) {
        amountAt = offset + m[0].length;
    } else {
        m = /^(.*?[a-z].*?)\s+([+-])\s*(?=\d)/.exec(rest);
        if (!m)
            return null;
        name = cleanName(original.substring(offset, offset + m[1].length));
        amountAt = offset + m[0].length;
    }
    var sign = m[m.length - 1] === "-" ? -1 : 1;
    var read = TP.parse(original.substring(amountAt), now, { keyword: true })[0];
    if (!read || read.kind !== "duration" || (name && read.label))
        return null;
    var it = intent("adjust", lang);
    it.delta = sign * read.ms;
    it.name = name || read.label;
    return it;
}

// « snooze », « snooze 10 », « snooze 10 min pâtes »
function readSnooze(original, work, offset) {
    var verb = COMMAND_GRAMMAR.all.snooze.exec(work.substring(offset));
    if (!verb)
        return null;
    var it = intent("snooze", langOf(work.substring(offset), "snooze"));
    var start = offset + verb[0].length;
    var n = /^\s*(\d{1,3})(?:\s*(?:minutes?|mins?|mn|m))?(?![a-z\d])/.exec(work.substring(start));
    if (n) {
        it.minutes = Snooze.minutes(parseInt(n[1]));
        if (!it.minutes)
            return null;
        start += n[0].length;
    }
    it.name = cleanName(original.substring(start));
    return it;
}

// « pause pâtes », « reprendre », « resume tea ». A text that reads as a new
// timer (« pause café 15 min ») is not a command.
function readPauseResume(original, work, offset, now) {
    var kinds = ["pause", "resume"];
    for (var i = 0; i < kinds.length; i++) {
        var verb = COMMAND_GRAMMAR.all[kinds[i]].exec(work.substring(offset));
        if (!verb)
            continue;
        var it = intent(kinds[i], langOf(work.substring(offset), kinds[i]));
        it.name = cleanName(original.substring(offset + verb[0].length));
        if (it.name && TP.parse(original, now).length > 0)
            return null;
        return it;
    }
    return null;
}

// The command in `input`, or null. options: { now } (only to read amounts)
function parseCommand(input, options) {
    if (!input || TP.tooLong(input))
        return null;
    options = options || {};
    var now = options.now || Date.now();
    var original = String(input);
    var work = TP.normalize(original);
    // A calculation (« = 2+2 ») is never a command
    if (/^\s*=/.test(work))
        return null;
    var offset = 0;
    var kw = TP.GRAMMAR.keyword.exec(work);
    if (kw)
        offset = kw[0].length;
    var lang = kw ? langOf(work, "keyword") : "";
    return readSnooze(original, work, offset)
        || readPauseResume(original, work, offset, now)
        || readRename(original, work, offset, lang)
        || readAdjust(original, work, offset, lang, now);
}

// A name folded for comparison: no accents, no case, no emoji
function fold(text) {
    return TP.normalize(Timers.stripEmoji(text, 0)).replace(/\s+/g, " ").trim();
}

// The timer a command acts on, or null. Without a name: the nearest one the
// command applies to (the ringing one, else the one that ends first; see
// Lifecycle.sortTimers). With a name: that timer (whole name first, then a
// name that starts with it, then one that contains it).
function resolveTarget(it, timers, now) {
    if (!it || !timers || !timers.length)
        return null;
    var state = STATES[it.kind];
    var list = Lifecycle.sortTimers(timers.filter(function (t) {
        return t && (!state || t.state === state);
    }));
    if (!it.name)
        return list.length ? list[0] : null;
    var key = fold(it.name);
    var tests = [
        function (n) { return n === key; },
        function (n) { return n.indexOf(key) === 0; },
        function (n) { return n.indexOf(key) > 0; }
    ];
    for (var i = 0; i < tests.length; i++) {
        for (var j = 0; j < list.length; j++) {
            if (tests[i](fold(Timers.displayLabel(list[j]))))
                return list[j];
        }
    }
    return null;
}

// What the launcher shows before Enter, or null when there is nothing to do:
// { text: « +5 min à Pâtes (finit à 18:47) », icon: a Material Symbols name,
//   at: the new end (0 when the timer will not run), changed: false when
//   Enter would change nothing (already at the 10 s floor, over the maximum) }.
// options: { lang: the interface language or locale name (else the
// command's, else English; the words are Strings.js "command.*"), use24 (default true), snoozeMinutes: the default snooze,
// maxMs: the longest timer (TP.MAX_MS) }
function previewCommand(it, target, now, options) {
    if (!it || !target)
        return null;
    options = options || {};
    var lang = Strings.langOf(options.lang || it.lang || "en");
    var name = target.label || Strings.tr(target.kind === "at" ? "name.alarm" : "name.timer", lang);
    // %1 the timer, then the amount, the new end and the new name
    var tr = function (key, a, b, c) {
        return Strings.tr("command." + key, lang, name, a, b, c);
    };
    var clock = function (at) {
        return TP.formatTimeOfDay(at, options.use24 !== false);
    };
    var out = { text: "", icon: ICONS[it.kind], at: 0, changed: true };
    if (it.kind === "adjust") {
        // The daemon's own rule on a copy, so the floor and the restart of a
        // ringing timer show exactly as Enter will do them
        var copy = JSON.parse(JSON.stringify(target));
        out.changed = Lifecycle.adjust(copy, now, it.delta, options.maxMs || TP.MAX_MS);
        out.at = copy.state === "running" ? copy.endAt : now + copy.remaining;
        out.text = tr("adjust", (it.delta < 0 ? "−" : "+") + TP.formatHuman(Math.abs(it.delta)), clock(out.at));
    } else if (it.kind === "pause") {
        out.text = tr("pause");
    } else if (it.kind === "resume") {
        out.at = now + Math.max(0, target.remaining);
        out.text = tr("resume", "", clock(out.at));
    } else if (it.kind === "snooze") {
        var minutes = it.minutes || Snooze.minutes(options.snoozeMinutes) || Snooze.DEFAULT_MINUTES;
        out.at = now + minutes * 60000;
        out.text = tr("snooze", TP.formatHuman(minutes * 60000), clock(out.at));
    } else if (it.kind === "rename") {
        out.changed = it.newName !== target.label;
        out.text = tr("rename", "", "", it.newName);
    }
    return out;
}
