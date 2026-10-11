// AlertPolicy.js tests — run with: gjs tests/alert-policy.test.js (from the plugin root)
// Which visual alert to draw and when: every kind x moment x sound x full screen.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const A = load("components/alert/AlertPolicy.js");

// Fall-backs
eq(A.kindOf(undefined), "dune", "missing kind");
eq(A.kindOf("sparkle"), "dune", "unknown kind");
eq([A.kindOf("dune"), A.kindOf("halo"), A.kindOf("none")], ["dune", "halo", "none"], "known kinds");
eq(A.whenOf(null), "muted", "missing moment");
eq(A.whenOf("never"), "muted", "unknown moment");
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
eq(A.legendReason("halo", "always", audible), "", "always, audible: nothing extra");
eq(A.legendReason("halo", "always", states["output muted"][0]), "Sound is muted", "always, muted");
eq(A.legendReason("dune", "muted", states["sound none"][0]), "No sound chosen", "no sound chosen");
eq(A.legendReason("none", "muted", states["volume 0"][0]), "", "no alert, no legend");

done();
