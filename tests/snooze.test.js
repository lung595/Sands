// Snooze.js tests — run with: gjs tests/snooze.test.js (from the plugin root)
// The snooze choices: validated, capped, last pick first.
imports.searchPath.unshift(imports.gi.GLib.path_get_dirname(imports.system.programPath));
const { load, eq, done } = imports.harness;
const S = load("components/daemon/Snooze.js");

eq(S.minutes(5), 5, "valid");
eq(S.minutes("10"), 10, "numeric text");
for (const bad of [0, -1, 1.5, 121, NaN, null, undefined, "x", [], {}, true])
    eq(S.minutes(bad), 0, "invalid " + JSON.stringify(bad));

eq(S.clean(undefined), [1, 5, 10], "missing: defaults");
eq(S.clean([]), [1, 5, 10], "empty: defaults");
eq(S.clean(["a", 0, -2]), [1, 5, 10], "all invalid: defaults");
eq(S.clean([10, 2, 10, "x", 2, 0]), [2, 10], "valid, distinct, ascending");
eq(S.clean([1, 2, 3, 4, 5, 6, 7, 8]), [1, 2, 3, 4, 5, 6], "capped at 6");
eq(S.clean(new Array(500).fill(7)), [7], "huge input stays cheap");
eq(S.clean("5"), [1, 5, 10], "not a list: defaults");

eq(S.ordered([1, 5, 10], 5), [5, 1, 10], "last pick first");
eq(S.ordered([1, 5, 10], 1), [1, 5, 10], "already first");
eq(S.ordered([1, 5, 10], 7), [1, 5, 10], "unknown last ignored");
eq(S.ordered([1, 5, 10], undefined), [1, 5, 10], "no last");
eq(S.ordered(undefined, 10), [10, 1, 5], "defaults with last");

eq(S.remember([1, 5, 10], 5), 5, "remember an offered choice");
eq(S.remember([1, 5, 10], 7), 0, "not offered: nothing");
eq(S.remember([1, 5, 10], "abc"), 0, "garbage: nothing");

eq(S.toMs(5), 300000, "ms");
eq(S.toMs(0), 0, "invalid: 0");
done();
