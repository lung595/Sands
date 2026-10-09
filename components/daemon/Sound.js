.pragma library

// Pure sound rules for the alarm, the preview and the tick: which file,
// how loud, which player. No QML, no side effects.

// The rings shipped in sounds/, in the order the Sound setting lists them.
// The first is the default and keeps the saved value "default": DMS's
// dropdown would save its label for an empty value instead (P126).
const RINGS = [
    { value: "default", label: "Hourglass", file: "hourglass.ogg" },
    { value: "silt-chime", label: "Silt Chime", file: "silt-chime.ogg" }
];

// The file to play for the "sound" setting. A ring's value plays that ring,
// a full path plays that file, and "" or anything else that is not a path,
// such as "Alarm clock (default)", the label DMS's dropdown saved by mistake
// (P126), plays the default ring. "custom" reads the "customSound" setting,
// where "~/" and "file://" are accepted. `ringDir` ends with "/".
function soundFile(choice, custom, home, ringDir) {
    if (choice === "custom") {
        const path = String(custom || "").trim().replace(/^file:\/\//, "").replace(/^~(?=\/)/, home);
        return path.startsWith("/") ? path : ringDir + RINGS[0].file;
    }
    if (typeof choice === "string" && choice.startsWith("/"))
        return choice;
    return ringDir + (RINGS.find(r => r.value === choice) || RINGS[0]).file;
}

// The "volume" setting as a 0..1 gain (80 % when unreadable)
function volumeOf(raw) {
    const v = parseInt(raw);
    return Math.max(0, Math.min(100, isNaN(v) ? 80 : v)) / 100;
}

// Rising alarm: 30 %, 65 %, then full volume (1 when the ramp is off)
function ramp(enabled, ringCount) {
    return enabled ? Math.min(1, 0.3 + 0.35 * ringCount) : 1;
}

// How long an alarm makes noise and moves, from the "ringDuration" setting
// (seconds, at least 5, 60 when unreadable)
function ringLimitMs(raw) {
    return Math.max(5, parseInt(raw) || 60) * 1000;
}

// The player command: pw-play, or paplay when pw-play failed. A list, never
// a shell string; `--` ends the options before the path.
function playerCommand(fallback, path, volume) {
    if (fallback)
        return ["paplay", "--volume=" + Math.round(volume * 65536), path];
    return ["pw-play", "--volume=" + volume.toFixed(2), "--", path];
}
