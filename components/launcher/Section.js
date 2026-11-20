.pragma library
.import "../daemon/Lifecycle.js" as Lifecycle
.import "../../Timers.js" as Timers

// The "Timers" row of the launcher (Super+Space), as data: which cards, in
// which order, and when the row shows at all. TimerLauncher.qml hands the
// result to DMS through getSectionItems(query); the cards only draw it.
// Pure, no clock, no state of its own. Tested by tests/launcher-section.test.js.
//
// An item follows the DMS getItems() format plus the live section keys:
//   { id, name, icon, comment, action, expandable, keepOpen, preferSelect,
//     kind: "timer" | "favourite" | "more" | "stopped", timerId, state, ms,
//     hidden }
// DMS hands the whole item to the card as launcherItem.data and back to
// executeItem(), so kind and timerId are read there.

// Cards shown before the "+N" card
var SLOTS = 4;
// Favourites never take more than this many places
var MAX_FAVOURITES = 3;
// The words that make a query a Sands command even without a prefix set
var COMMAND_WORDS = /^(timer|minuteur|minuterie|countdown)(\s|$)/i;

// "Minuteurs" or "Timers", from the DMS language ("fr", "fr_FR", "en_US")
function title(lang) {
    return /^fr/i.test(String(lang || "")) ? "Minuteurs" : "Timers";
}

// The header: the bare title, or "Minuteurs · 6" once some timers are hidden
// behind the "+N" card
function header(lang, timerCount) {
    return timerCount > SLOTS ? title(lang) + " · " + timerCount : title(lang);
}

// True when the query is meant for Sands: it starts with the prefix set in
// the settings (DMS hands the query with it), or with a timer word
function isCommand(query, trigger) {
    const q = String(query || "").trim();
    const t = String(trigger || "").trim();
    if (t !== "" && q.toLowerCase().startsWith(t.toLowerCase()))
        return true;
    return COMMAND_WORDS.test(q);
}

// The order of the cards as [{ id, state }]: ringing, then running (the
// soonest end first), then paused. `prev` is the order returned last time:
// it is kept as long as the same timers are there in the same states, so
// +1 min or a tick never moves a card. With `hold` (a card is open, the
// pointer is over the row) it is kept even then: known timers stay in place,
// new ones go at the end, gone ones leave.
function order(timers, prev, hold) {
    const list = Array.isArray(timers) ? timers : [];
    const sorted = Lifecycle.sortTimers(list).map(t => ({ "id": t.id, "state": t.state }));
    if (!Array.isArray(prev) || prev.length === 0)
        return sorted;
    const byId = {};
    for (const t of list)
        byId[t.id] = t;
    const same = prev.length === list.length && prev.every(p => byId[p.id] && byId[p.id].state === p.state);
    if (same)
        return prev.map(p => ({ "id": p.id, "state": p.state }));
    if (!hold)
        return sorted;
    const kept = prev.filter(p => byId[p.id]).map(p => ({ "id": p.id, "state": byId[p.id].state }));
    const known = {};
    for (const p of kept)
        known[p.id] = true;
    return kept.concat(sorted.filter(s => !known[s.id]));
}

// How many favourites fit next to `timerCount` timers: 0 → 3, 1 → 3, 2 → 2,
// 3 → 1, 4 or more → 0
function favouriteSlots(timerCount) {
    return Math.max(0, Math.min(MAX_FAVOURITES, SLOTS - Math.max(0, timerCount)));
}

// Whether the row shows. `o` = { timers, favourites (counts), query, command,
// settings: { section, duringSearch, favourites } }. A Sands command always
// shows it; otherwise it follows the settings.
function visible(o) {
    const s = o.settings || {};
    const hasTimers = o.timers > 0;
    const hasFavourites = s.favourites !== false && o.favourites > 0;
    if (!hasTimers && !hasFavourites)
        return false;
    if (o.command)
        return true;
    if (s.section === false)
        return false;
    if (String(o.query || "").trim() !== "" && s.duringSearch === false)
        return false;
    return true;
}

function _icon(state) {
    return state === "ringing" ? "material:alarm" : (state === "paused" ? "material:pause_circle" : "material:timer");
}

function _timerItem(t, preferSelect) {
    const ringing = t.state === "ringing";
    return {
        "id": "timer:" + t.id,
        "name": Timers.displayLabel(t),
        "icon": _icon(t.state),
        "comment": "",
        // Ringing: Enter stops it (the click opens it, in the card). Else Enter opens the card.
        "action": (ringing ? "stop:" : "toggle:") + t.id,
        "expandable": !ringing,
        "keepOpen": true,
        "preferSelect": preferSelect,
        "kind": "timer",
        "timerId": t.id,
        "state": t.state
    };
}

function _favouriteItem(f) {
    return {
        "id": "favourite:" + f.name,
        "name": f.name,
        "icon": "material:timer",
        "comment": f.duration || "",
        "action": "start:" + JSON.stringify({ "ms": f.ms, "label": f.name, "kind": "duration", "at": 0, "count": 1 }),
        "expandable": false,
        "keepOpen": false,
        "preferSelect": false,
        "kind": "favourite",
        "ms": f.ms
    };
}

// A timer stopped from its card, kept in place for the undo window: Enter
// (or the card's button) brings it back
function _stoppedItem(t, at) {
    return {
        "id": "timer:" + t.id,
        "name": Timers.displayLabel(t),
        "icon": "material:undo",
        "comment": "",
        "action": "undo:" + t.id,
        "expandable": false,
        "keepOpen": true,
        "preferSelect": false,
        "kind": "stopped",
        "timerId": t.id,
        "state": "stopped",
        "at": at || 0
    };
}

// `ord` with the timers stopped less than `undoMs` ago put back where they
// were in `prev`, as { id, state: "stopped" }
function withStopped(ord, prev, removed, now, undoMs) {
    const gone = {};
    for (const r of Array.isArray(removed) ? removed : [])
        if (r && r.timer && now - r.at < undoMs)
            gone[r.timer.id] = true;
    const out = ord.slice();
    (Array.isArray(prev) ? prev : []).forEach((p, i) => {
        if (gone[p.id] && !out.some(x => x.id === p.id))
            out.splice(Math.min(i, out.length), 0, { "id": p.id, "state": "stopped" });
    });
    return out;
}

// The "+N" card: opens the first hidden timer, the others are listed in it
function _moreItem(hidden, first) {
    return {
        "id": "more",
        "name": "+" + hidden,
        "icon": "material:more_horiz",
        "comment": "",
        "action": "toggle:" + first.id,
        "expandable": true,
        "keepOpen": true,
        "preferSelect": false,
        "kind": "more",
        "timerId": first.id,
        "hidden": hidden
    };
}

// The cards of the row and the order to keep for next time.
// `o` = { timers, favourites (Pins.pins() entries), query, trigger,
//         settings: { section, duringSearch, favourites }, prev, hold,
//         removed (the daemon's [{ timer, at }]), now }
// Returns { items, order }; no item means DMS hides the row.
function build(o) {
    const timers = Array.isArray(o.timers) ? o.timers : [];
    const settings = o.settings || {};
    const prevLive = Array.isArray(o.prev) ? o.prev.filter(p => p.state !== "stopped") : o.prev;
    const ord = withStopped(order(timers, prevLive, o.hold), o.prev, o.removed, o.now || 0, Lifecycle.UNDO_MS);
    const running = {};
    for (const t of timers)
        running[Timers.displayLabel(t).toLowerCase()] = true;
    // A favourite already running is not offered again
    const favs = settings.favourites === false ? [] : (Array.isArray(o.favourites) ? o.favourites : []).filter(f => f && f.name && !running[String(f.name).toLowerCase()]);
    const shown = visible({
        "timers": ord.length,
        "favourites": favs.length,
        "query": o.query,
        "command": isCommand(o.query, o.trigger),
        "settings": settings
    });
    if (!shown)
        return { "items": [], "order": ord };

    const byId = {};
    const stoppedAt = {};
    for (const r of Array.isArray(o.removed) ? o.removed : [])
        if (r && r.timer) {
            byId[r.timer.id] = r.timer;
            stoppedAt[r.timer.id] = r.at;
        }
    for (const t of timers)
        byId[t.id] = t;
    const queryEmpty = String(o.query || "").trim() === "";
    const items = [];
    let selectGiven = false;
    for (const p of ord.slice(0, SLOTS)) {
        const t = byId[p.id];
        if (p.state === "stopped") {
            items.push(_stoppedItem(t, stoppedAt[p.id]));
            continue;
        }
        const prefer = queryEmpty && !selectGiven && t.state === "ringing";
        selectGiven = selectGiven || prefer;
        items.push(_timerItem(t, prefer));
    }
    // "+N" counts the live hidden timers only. A hidden timer just stopped
    // (the one "+N" opened) takes its place as "Stopped · Undo" once no
    // other is hidden.
    const hiddenLive = ord.slice(SLOTS).filter(p => p.state !== "stopped");
    const hiddenStopped = ord.slice(SLOTS).filter(p => p.state === "stopped");
    if (hiddenLive.length > 0)
        items.push(_moreItem(hiddenLive.length, byId[hiddenLive[0].id]));
    else if (hiddenStopped.length > 0)
        items.push(_stoppedItem(byId[hiddenStopped[0].id], stoppedAt[hiddenStopped[0].id]));
    for (const f of favs.slice(0, favouriteSlots(timers.length)))
        items.push(_favouriteItem(f));
    return { "items": items, "order": ord };
}

// Asks DMS to refresh the row in place. `seen` says DMS has already asked for
// the row (getSectionItems): only a DMS with live sections does. Every DMS
// declares the requestLauncherUpdate signal, and an older one answers it by
// running the open search again, so without `seen` nothing is called.
function requestUpdate(service, pluginId, seen) {
    if (!seen || !service || typeof service.requestLauncherUpdate !== "function")
        return false;
    service.requestLauncherUpdate(pluginId);
    return true;
}
