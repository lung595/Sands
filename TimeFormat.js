.pragma library

// How Sands writes a time: countdowns, durations, clock times. Pure, no
// import, no QML: every view and module formats through here (TimeParser.js
// still re-exports these names for the callers that import it as TP).
//
// Clock times follow the DMS 12/24 h choice, which this module never reads:
// the caller passes it (see use24h and CONTRIBUTING, "12/24 h clock").

function pad(n) {
    return n < 10 ? "0" + n : "" + n;
}

// The DMS clock choice as a boolean: 24 h unless the setting is exactly
// false (missing or not loaded yet reads as 24 h, like formatTimeOfDay).
// Views pass SettingsData.use24HourClock.
function use24h(setting) {
    return setting !== false;
}

// Countdown, rounded up to the next second: 20:00 at the start, 0:00
// exactly when it rings. Negative = time elapsed since the end (« −0:12 »).
function formatClock(ms) {
    var neg = ms < 0;
    var s = neg ? Math.floor(-ms / 1000) : Math.ceil(ms / 1000);
    var h = Math.floor(s / 3600);
    var mn = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var txt = h > 0 ? h + ":" + pad(mn) + ":" + pad(sec) : mn + ":" + pad(sec);
    return (neg && s > 0 ? "−" : "") + txt;
}

// Readable duration: « 1 h 30 », « 20 min », « 1 min 30 s », « 45 s ».
function formatHuman(ms) {
    var s = Math.round(ms / 1000);
    var h = Math.floor(s / 3600);
    var mn = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    if (h > 0)
        return mn > 0 ? h + " h " + pad(mn) : h + " h";
    if (mn > 0)
        return sec > 0 ? mn + " min " + sec + " s" : mn + " min";
    return sec + " s";
}

// Duration rounded to the minute, for « dans 2 h 16 » ("in 2 h 16").
function formatRelative(ms) {
    var mnTotal = Math.round(ms / 60000);
    if (mnTotal < 1)
        return formatHuman(ms);
    var h = Math.floor(mnTotal / 60);
    var mn = mnTotal % 60;
    if (h > 0)
        return mn > 0 ? h + " h " + pad(mn) : h + " h";
    return mn + " min";
}

// Wall-clock time of `epoch`, the way DMS writes it: "HH:mm" with use24
// true or missing (« 18:42 », « 08:05 »), "h:mm AP" with use24 false
// (« 6:42 PM », « 12:00 AM » at midnight).
function formatTimeOfDay(epoch, use24) {
    var d = new Date(epoch);
    var h = d.getHours();
    var mn = pad(d.getMinutes());
    if (use24 === false) {
        var h12 = h % 12 === 0 ? 12 : h % 12;
        return h12 + ":" + mn + (h >= 12 ? " PM" : " AM");
    }
    return pad(h) + ":" + mn;
}

function isTomorrow(epoch, now) {
    // The calendar day after today, like the parser's « tomorrow »: not merely another day.
    var next = new Date(now || Date.now());
    next.setDate(next.getDate() + 1);
    return new Date(epoch).toDateString() === next.toDateString();
}

// Fixed-width template (digits replaced by 0) so the pill does not move
// every second.
function widthTemplate(text) {
    return text.replace(/\d/g, "0");
}
