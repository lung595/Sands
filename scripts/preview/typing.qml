import QtQml
import "../../TimeParser.js" as TP

// Bench scene: types into the launcher parser like a user, one keystroke per
// tick, so banc-ab.sh can compare what TimeParser.js costs per keystroke.
// Nothing is drawn: the launcher list itself is not part of the parser cost.
// Usage: qml-qt6 typing.qml -- <mode> /dev/null
// Modes: typical (everyday phrases), worst (200 characters of number + word
// pairs, the most work for the unit typo pass), cap (over MAX_INPUT, refused
// before parsing). Suffix "-xN" parses each prefix N times (stress).
QtObject {
    id: bench

    readonly property var args: Qt.application.arguments
    readonly property string rawMode: args[args.length - 2]
    readonly property string mode: rawMode.split("-")[0]
    readonly property int reps: rawMode.indexOf("-x") > 0 ? parseInt(rawMode.split("-x")[1]) : 1

    function repeatTo(unit, n) {
        let s = "";
        while (s.length < n)
            s += unit;
        return s.slice(0, n);
    }

    readonly property var phrases: mode === "worst" ? [repeatTo("5 aaaa ", 200), repeatTo("vingt minuts ", 200), repeatTo("12 heurs pasta ", 200)] : (mode === "cap" ? [repeatTo("5 aaaa ", 260)] : ["rappelle-moi de sortir le linge dans vingt minutes", "pasta 12", "firefox", "12 min pasta", "remind me to call mom in half an hour", "tea 4 minuts", "at 6pm leave"])

    property int phrase: 0
    property int typed: 0

    // 30 keystrokes a second: faster than anyone types, so an upper bound
    property Timer keys: Timer {
        interval: 33
        repeat: true
        running: true
        onTriggered: {
            const text = bench.phrases[bench.phrase];
            bench.typed = bench.typed >= text.length ? 1 : bench.typed + 1;
            if (bench.typed === 1)
                bench.phrase = (bench.phrase + 1) % bench.phrases.length;
            const q = bench.phrases[bench.phrase].slice(0, bench.typed);
            for (let i = 0; i < bench.reps; i++) {
                if (TP.tooLong(q))
                    continue;
                // The launcher parses once per keystroke, with or without the trigger
                TP.parse(q, Date.now(), {
                    keyword: i % 2 === 0
                });
            }
        }
    }
}
