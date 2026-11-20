// components/launcher/Section.js tests — run with: gjs tests/launcher-section.test.js (from the plugin root)
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const S = load("components/launcher/Section.js");

const run = (id, endAt, label) => ({ id, label: label || "", kind: "duration", state: "running", endAt, total: 60000, remaining: 0, finishedAt: 0 });
const pause = (id, remaining, label) => ({ id, label: label || "", kind: "duration", state: "paused", endAt: 0, total: 60000, remaining, finishedAt: 0 });
const ring = (id, finishedAt, label) => ({ id, label: label || "", kind: "duration", state: "ringing", endAt: finishedAt, total: 60000, remaining: 0, finishedAt });
const fav = (name, ms) => ({ name, ms, duration: Math.round(ms / 60000) + "m" });
const ON = { section: true, duringSearch: true, favourites: true };
const build = o => S.build(Object.assign({ timers: [], favourites: [], query: "", trigger: "", settings: ON }, o));
const kinds = r => r.items.map(i => i.kind);
const ids = r => r.items.map(i => i.id);
const favs3 = [fav("Pasta", 600000), fav("Tea", 240000), fav("Oven", 1800000), fav("Eggs", 420000)];

// Header: by language, the count only once timers are hidden
eq([S.title("fr"), S.title("fr_FR"), S.title("en_US"), S.title(""), S.title(undefined)], ["Minuteurs", "Minuteurs", "Timers", "Timers", "Timers"], "title by DMS language");
eq([S.header("fr", 4), S.header("fr", 5), S.header("en", 7), S.header("en", 0)], ["Minuteurs", "Minuteurs · 5", "Timers · 7", "Timers"], "count only beyond 4 timers");

// Order: ringing, running by nearest end, paused, then favourites
const mixed = [pause(1, 5000), run(2, 9000), ring(3, 100), run(4, 3000)];
eq(S.order(mixed, null).map(p => p.id), [3, 4, 2, 1], "ringing, running by end, paused");
eq(kinds(build({ timers: [run(1, 9000)], favourites: favs3 })), ["timer", "favourite", "favourite", "favourite"], "timers before favourites");

// Stable order: kept while the same timers keep their states
const first = S.order([run(1, 5000), run(2, 9000)], null);
eq(first.map(p => p.id), [1, 2], "first order");
eq(S.order([run(1, 99000), run(2, 9000)], first).map(p => p.id), [1, 2], "+time on a timer does not move it");
eq(S.order([pause(1, 4000), run(2, 9000)], first).map(p => p.id), [2, 1], "a state change sorts again");
eq(S.order([run(1, 5000), run(2, 9000), run(3, 1000)], first).map(p => p.id), [3, 1, 2], "a new timer sorts again");
eq(S.order([run(2, 9000)], first).map(p => p.id), [2], "a gone timer sorts again");
eq(S.order([pause(1, 4000), run(2, 9000), run(3, 1000)], first, true).map(p => p.id), [1, 2, 3], "held: known stay in place, new at the end");
eq(S.order([pause(1, 4000), run(2, 9000)], first, true)[0].state, "paused", "held order carries the new state");
eq(S.order([run(2, 9000)], first, true).map(p => p.id), [2], "held: a gone timer leaves");
eq(S.order([], first), [], "no timer, empty order");
eq(build({ timers: [run(1, 5000), run(2, 9000)] }).order.map(p => p.id), [1, 2], "build returns the order to keep");
eq(ids(build({ timers: [run(1, 99000), run(2, 9000)], prev: first })), ["timer:1", "timer:2"], "build keeps the previous order");

// 4 places, then "+N" counting only the hidden timers
const many = n => Array.from({ length: n }, (_, i) => run(i + 1, 1000 * (i + 1)));
eq(kinds(build({ timers: many(4), favourites: favs3 })), ["timer", "timer", "timer", "timer"], "4 timers: no favourite, no +N");
const five = build({ timers: many(5) });
eq(kinds(five), ["timer", "timer", "timer", "timer", "more"], "5 timers: 4 cards and +N");
eq([five.items[4].name, five.items[4].hidden, five.items[4].timerId], ["+1", 1, 5], "+1 opens the 5th timer");
const seven = build({ timers: many(7), favourites: favs3 });
eq([seven.items.length, seven.items[4].name, seven.items[4].hidden], [5, "+3", 3], "7 timers: +3, no favourite");
eq([seven.items[4].expandable, seven.items[4].keepOpen], [true, true], "+N unfolds in place");

// Favourites fill the free places, at most 3
eq(S.favouriteSlots(0), 3, "0 timer: 3 favourites");
eq(S.favouriteSlots(1), 3, "1 timer: 3 favourites");
eq(S.favouriteSlots(2), 2, "2 timers: 2 favourites");
eq(S.favouriteSlots(3), 1, "3 timers: 1 favourite");
eq([S.favouriteSlots(4), S.favouriteSlots(9)], [0, 0], "4 or more: none");
eq(kinds(build({ favourites: favs3 })), ["favourite", "favourite", "favourite"], "no timer: 3 favourites");
eq(kinds(build({ timers: many(2), favourites: favs3 })), ["timer", "timer", "favourite", "favourite"], "2 timers: 2 favourites");
eq(ids(build({ timers: [run(1, 5000, "Pasta")], favourites: favs3 })), ["timer:1", "favourite:Tea", "favourite:Oven", "favourite:Eggs"], "a favourite already running is not offered");
eq(ids(build({ timers: [run(1, 5000, "pasta")], favourites: favs3 })).includes("favourite:Pasta"), false, "the running match ignores case");

// Item shapes, per the DMS contract
const fv = build({ favourites: [fav("Pasta", 600000)] }).items[0];
eq([fv.id, fv.name, fv.comment, fv.kind, fv.ms, fv.expandable, fv.keepOpen, fv.preferSelect], ["favourite:Pasta", "Pasta", "10m", "favourite", 600000, false, false, false], "favourite card starts at once");
eq(JSON.parse(fv.action.slice(6)), { ms: 600000, label: "Pasta", kind: "duration", at: 0, count: 1 }, "favourite action is a start");

// Names: written with a capital, like the preview rows below the cards (« Thé · 4 min »)
const typed = build({ timers: [run(1, 3000, "thé"), pause(2, 5000, "pâtes")], favourites: [fav("four", 1800000)] });
eq(typed.items.map(i => i.name), ["Thé", "Pâtes", "Four"], "timer and favourite names get a capital");
eq(JSON.parse(typed.items[2].action.slice(6)).label, "four", "a favourite still starts under its own name");
const tm = build({ timers: [run(7, 5000, "Tea")] }).items[0];
eq([tm.id, tm.name, tm.kind, tm.timerId, tm.state, tm.expandable, tm.keepOpen, tm.action, tm.icon], ["timer:7", "Tea", "timer", 7, "running", true, true, "toggle:7", "material:timer"], "running card unfolds");
eq(build({ timers: [run(8, 5000)] }).items[0].name, "Timer", "unnamed timer gets the default name");
eq(build({ timers: [pause(9, 5000)] }).items[0].icon, "material:pause_circle", "paused icon");
const rg = build({ timers: [ring(3, 100, "Pasta")] }).items[0];
eq([rg.expandable, rg.keepOpen, rg.action, rg.icon], [false, true, "stop:3", "material:alarm"], "ringing: Enter stops, the launcher stays");

// preferSelect: the ringing card, only with an empty query, only one
eq(build({ timers: [ring(3, 100), run(1, 5000)] }).items.map(i => i.preferSelect), [true, false], "ringing card takes the selection");
eq(build({ timers: [ring(3, 100), run(1, 5000)], query: "fir" }).items.map(i => i.preferSelect), [false, false], "never while typing");
eq(build({ timers: [ring(3, 100), ring(4, 200)] }).items.map(i => i.preferSelect), [true, false], "only the first ringing card");
eq(build({ timers: [run(1, 5000)], favourites: favs3 }).items.some(i => i.preferSelect), false, "nothing ringing: no preferSelect");

// Visibility
eq(ids(build({})), [], "nothing at all: no row");
eq(build({ timers: [pause(1, 5000)] }).items.length, 1, "any timer shows the row");
eq(build({ favourites: favs3, settings: { section: true, duringSearch: true, favourites: false } }).items, [], "favourites off: no favourite-only row");
eq(kinds(build({ timers: many(1), favourites: favs3, settings: { section: true, duringSearch: true, favourites: false } })), ["timer"], "favourites off: timers only");
eq(build({ timers: many(1), settings: { section: false, duringSearch: true, favourites: true } }).items, [], "section off: no row");
eq(build({ timers: many(1), query: "fir" }).items.length, 1, "during a search: shown by default");
eq(build({ timers: many(1), query: "fir", settings: { section: true, duringSearch: false, favourites: true } }).items, [], "during a search: hidden when off");
eq(build({ timers: many(1), query: "  ", settings: { section: true, duringSearch: false, favourites: true } }).items.length, 1, "blank query is no search");
const off = { section: false, duringSearch: false, favourites: true };
eq(build({ timers: many(1), query: "timer 5", settings: off }).items.length, 1, "a timer word always shows the row");
eq(build({ timers: many(1), query: "minuteur", settings: off }).items.length, 1, "French timer word too");
eq(build({ timers: many(1), query: "tm 5", trigger: "tm", settings: off }).items.length, 1, "the prefix set in the settings too");
eq(build({ favourites: favs3, query: "timer", settings: off }).items.length, 3, "command with favourites only");
eq(build({ query: "timer", settings: off }).items, [], "command with nothing to show: no row");
eq([S.isCommand("timer", ""), S.isCommand("Timer 5m", ""), S.isCommand("timers", ""), S.isCommand("firefox", ""), S.isCommand("t 5", "t"), S.isCommand("", "")], [true, true, false, false, true, false], "command detection");
eq(S.visible({ timers: 0, favourites: 2, query: "", command: false, settings: ON }), true, "visible with favourites");
eq(S.visible({ timers: 0, favourites: 0, query: "", command: true, settings: ON }), false, "never an empty row");
eq(S.visible({ timers: 1, favourites: 0, query: "", command: false, settings: {} }), true, "missing settings mean on");

// The refresh call waits until DMS has asked for the row: every DMS declares
// requestLauncherUpdate, and one without live sections runs its search again
const calls = [];
const dms = { requestLauncherUpdate: id => calls.push(id) };
eq(S.requestUpdate(dms, "smartTimer", false), false, "row never asked for: not called");
eq(S.requestUpdate(dms, "smartTimer"), false, "seen missing: not called");
eq(calls, [], "the signal of an older DMS is never fired");
eq(S.requestUpdate(dms, "smartTimer", true), true, "DMS with live sections is asked");
eq(calls, ["smartTimer"], "with the plugin id");
eq([S.requestUpdate({}, "smartTimer", true), S.requestUpdate(null, "smartTimer", true)], [false, false], "no signal or no service: nothing called");

// Wiring: plugin.json opts in without raising the DMS floor, and the daemon
// asks for a refresh when the timers change, never from its clock
const GLib = imports.gi.GLib;
const root = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath, GLib.get_current_dir())));
const text = f => new TextDecoder().decode(GLib.file_get_contents(root + "/" + f)[1]);
const manifest = JSON.parse(text("plugin.json"));
eq([manifest.launcherSection, manifest.requires_dms], [true, ">=1.6.0"], "plugin.json opts in, DMS floor unchanged");
const daemon = text("TimerDaemon.qml");
eq(/onTimersChanged: Section\.requestUpdate\(PluginService, pluginId, liveSections\)/.test(daemon), true, "the daemon refreshes the row on timersChanged, once DMS asked for it");
eq(/property bool liveSections: false/.test(daemon), true, "live sections off until DMS asks for the row");
eq(/getSectionItems\(query\) \{[^}]*d\.liveSections = true/.test(text("TimerLauncher.qml")), true, "getSectionItems turns them on");
eq((daemon.match(/requestUpdate|requestLauncherUpdate/g) || []).length, 1, "and nowhere else (not on the clock)");

done();
