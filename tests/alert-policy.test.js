// AlertPolicy.js tests — run with: gjs tests/alert-policy.test.js (from the plugin root)
// Which visual alert to draw and when: every kind x moment x sound x full screen.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const A = load("components/alert/AlertPolicy.js");

// Fall-backs
eq(A.kindOf(undefined), "dune", "missing kind");
eq(A.kindOf("sparkle"), "dune", "unknown kind");
eq([A.kindOf("dune"), A.kindOf("halo"), A.kindOf("none")], ["dune", "halo", "none"], "known kinds");
eq(A.whenOf(null), "always", "missing moment");
eq(A.whenOf("never"), "always", "unknown moment");
eq(A.whenOf("always"), "always", "known moment");

const audible = { choice: "default", volume: 0.8, outputMuted: false, hasOutput: true };
const states = {
    audible: [audible, false],
    "sound none": [{ ...audible, choice: "none" }, true],
    "volume 0": [{ ...audible, volume: 0 }, true],
    "output muted": [{ ...audible, outputMuted: true }, true],
    "no output": [{ ...audible, hasOutput: false }, true],
    unknown: [undefined, false]
};

// Every combination
for (const kind of ["dune", "halo", "none", "bogus", undefined])
    for (const when of ["muted", "always", "bogus", undefined])
        for (const [name, [state, inaudible]] of Object.entries(states))
            for (const fs of [false, true])
                for (const over of [false, true]) {
                    const k = A.kindOf(kind), w = A.whenOf(when);
                    const want = k !== "none" && (!fs || over) && (w === "always" || inaudible);
                    eq(A.shouldShow(kind, when, state, fs, over), want, `${kind}/${when}/${name}/fs ${fs}/over ${over}`);
                }

// Silent page warning: only sound none + visual none
eq(A.isSilent("none", "none"), true, "silent");
eq(A.isSilent("none", "halo"), false, "sound none, halo");
eq(A.isSilent("default", "none"), false, "sound, visual none");
eq(A.isSilent("none", "bogus"), false, "bogus kind falls back to dune");

// Legend
eq(A.legendReason("dune", "muted", states["volume 0"][0]), "Sound is muted", "muted legend");
eq(A.legendReason("halo", "always", audible), "Click to stop", "always, audible: click to stop");
eq(A.legendReason("halo", "muted", audible), "", "muted, audible: not shown, no text");
eq(A.legendReason("halo", "always", states["output muted"][0]), "Sound is muted", "always, muted");
eq(A.legendReason("dune", "muted", states["sound none"][0]), "No sound chosen", "no sound chosen");
eq(A.legendReason("none", "muted", states["volume 0"][0]), "", "no alert, no legend");

// Several timers ending together: one alert, named after the last to ring
const ring = (id, at, state = "ringing") => ({ id, state, finishedAt: at });
eq(A.lastRinging([ring(1, 100), ring(2, 300), ring(3, 200)]).id, 2, "latest finishedAt wins");
eq(A.lastRinging([ring(1, 100, "running"), ring(2, 50)]).id, 2, "running timers are ignored");
eq(A.lastRinging([ring(1, 100, "paused")]), null, "none ringing");
eq(A.lastRinging(undefined), null, "no list");

// Which screens show the alert ("alertScreen"): all, the focused one, or one by name
const two = ["DP-2", "HDMI-A-1"];
eq([A.DEFAULT_SCREEN, A.SCREEN_ALL, A.SCREEN_FOCUSED], ["all", "all", "focused"], "the saved words");
eq([A.screenOf(undefined), A.screenOf(null), A.screenOf(""), A.screenOf(7), A.screenOf("DP-2")], ["all", "all", "all", "all", "DP-2"], "a missing or bad choice is all screens");
eq(A.screensFor("all", two, "DP-2"), two, "all: every screen");
eq(A.screensFor(undefined, two, "DP-2"), two, "unset: every screen, as before the setting");
eq(A.screensFor("", two, ""), two, "empty: every screen");
eq(A.screensFor("focused", two, "HDMI-A-1"), ["HDMI-A-1"], "focused: the screen with the focus");
eq(A.screensFor("focused", two, "DP-2"), ["DP-2"], "focused: the other one");
eq(A.screensFor("focused", two, ""), two, "focused, focus unknown: every screen");
eq(A.screensFor("focused", two, undefined), two, "focused, no answer: every screen");
eq(A.screensFor("focused", two, "eDP-1"), two, "focused on a screen that is not listed: every screen");
eq(A.screensFor("DP-2", two, "HDMI-A-1"), ["DP-2"], "named and plugged in: that screen, whatever the focus");
eq(A.screensFor("HDMI-A-1", two, ""), ["HDMI-A-1"], "named, the second screen");
eq(A.screensFor("HDMI-A-1", ["DP-2"], "DP-2"), ["DP-2"], "named but unplugged: every screen left");
eq(A.screensFor("DP-9", two, "DP-2"), two, "named but unknown: every screen, never none");
eq(A.screensFor("dp-2", two, ""), two, "names are exact: another case is another screen");
for (const s of ["all", "focused", "DP-2", undefined])
    for (const list of [[], undefined, null])
        eq(A.screensFor(s, list, "DP-2"), [], `no screen at all (${s}): nothing to choose`);
eq(A.screensFor("all", ["DP-2", "", null, "HDMI-A-1"], ""), two, "nameless entries are dropped");
for (const s of ["all", "focused", "DP-2", "HDMI-A-1", "DP-9", "", undefined])
    for (const f of ["DP-2", "HDMI-A-1", "eDP-1", "", undefined]) {
        const got = A.screensFor(s, two, f);
        eq(got.length >= 1 && got.every(n => two.includes(n)), true, `never zero screen, never a stranger (${s}/${f})`);
    }
eq(two, ["DP-2", "HDMI-A-1"], "the list handed in is not changed");

// The windows keep the screens named at the ring point; none left means all
const scr = [{ name: "DP-2", model: "Wide 27" }, { name: "HDMI-A-1", model: "" }];
eq(A.pickScreens(scr, ["HDMI-A-1"]).map(s => s.name), ["HDMI-A-1"], "one screen kept");
eq(A.pickScreens(scr, two).map(s => s.name), two, "both kept, in screen order");
eq(A.pickScreens(scr, []).map(s => s.name), two, "no name: all");
eq(A.pickScreens(scr, undefined).map(s => s.name), two, "no list: all");
eq(A.pickScreens(scr, ["DP-9"]).map(s => s.name), two, "the named screen was unplugged during the ring: all");
eq(A.pickScreens([], ["DP-2"]), [], "no screen");
eq(A.pickScreens(undefined, ["DP-2"]), [], "no screen list");

// The rows of "Show on"
eq(A.screenChoices(scr, "all"), [
    { label: "All screens", value: "all" },
    { label: "Active screen", value: "focused" },
    { label: "Wide 27 (DP-2)", value: "DP-2" },
    { label: "HDMI-A-1", value: "HDMI-A-1" }
], "all, active, then one row per screen: model and output name, or the bare name");
eq(A.screenChoices(scr, "DP-2").length, 4, "a saved screen that is plugged in adds no row");
eq(A.screenChoices([scr[0]], "HDMI-A-1").slice(-1), [{ label: "HDMI-A-1 (not connected)", value: "HDMI-A-1" }], "a saved screen that is unplugged stays listed, marked");
eq(A.screenChoices([], undefined).map(o => o.value), ["all", "focused"], "no screen: the two general rows");
eq(A.screenChoices(undefined, "focused").map(o => o.value), ["all", "focused"], "no list");
eq(A.screenChoices([scr[0], scr[0], { name: "" }, null], "all").map(o => o.value), ["all", "focused", "DP-2"], "doubles and nameless screens are skipped");
const twins = A.screenChoices([{ name: "DP-1", model: "Twin" }, { name: "DP-2", model: "Twin" }], "all").map(o => o.label);
eq(new Set(twins).size, twins.length, "two screens of the same model keep distinct labels");
eq(A.screenChoices(scr, "DP-9").some(o => o.label.includes("\u2014")), false, "no long dash in a label");

done();
