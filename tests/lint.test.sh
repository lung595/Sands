#!/bin/sh
# Test of scripts/lint.sh: the repository passes against its baseline; on
# made-up QML files with a throw-away baseline, --update records the warnings,
# moving code down does not count as new, and a new warning or a syntax error
# fails with its file and line. Run: sh tests/lint.test.sh
here=$(cd "$(dirname "$0")" && pwd)
lint=$(dirname "$here")/scripts/lint.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
check() {
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got $2, want $3)"; fails=$((fails + 1)); fi
}
has() {
    if printf '%s' "$2" | grep -qF -- "$3"; then echo "ok   $1"; else echo "FAIL $1: no \"$3\" in"; printf '%s\n' "$2"; fails=$((fails + 1)); fi
}

out=$(sh "$lint" 2>&1); rc=$?
check "the repository has no new warning" "$rc" 0
has "it says so" "$out" "nothing new"

export SANDS_LINT_BASELINE="$work/baseline.txt"
cat >"$work/Box.qml" <<'QML'
import QtQuick
Item {
    id: box
    Item { width: nope }
}
QML
sh "$lint" --update "$work/Box.qml" >/dev/null 2>&1
check "--update writes the baseline" "$(grep -c 'Unqualified access' "$work/baseline.txt")" 1
has "an entry carries the code, not the line" "$(cat "$work/baseline.txt")" "unqualified	Unqualified access	nope"
check "no line number in the baseline" "$(grep -c ':4:' "$work/baseline.txt")" 0

sh "$lint" "$work/Box.qml" >/dev/null 2>&1
check "known warnings pass" "$?" 0

# The same warning three lines further down is still the known one
cat >"$work/Box.qml" <<'QML'
import QtQuick


Item {
    id: box

    Item { width: nope }
}
QML
sh "$lint" "$work/Box.qml" >/dev/null 2>&1
check "moved code is not new" "$?" 0

# The same warning once more counts, and so does another one
cat >"$work/Box.qml" <<'QML'
import QtQuick


Item {
    id: box

    Item { width: nope }
    Item { height: nope }
    property int depth: box.missingThing
}
QML
out=$(sh "$lint" "$work/Box.qml" 2>&1); rc=$?
check "a new warning fails" "$rc" 1
has "the count is printed" "$out" "lint: 2 new warnings"
has "the missing member is named with its line" "$out" "Box.qml:9:"
has "the message is printed" "$out" 'Member "missingThing" not found'
has "the second unqualified access is counted as one new" "$out" "(1 new)"

printf 'import QtQuick\nItem {\n  width: foo(\n}\n' >"$work/Broken.qml"
out=$(sh "$lint" "$work/Broken.qml" 2>&1); rc=$?
check "a syntax error fails" "$rc" 1
has "it is printed as such" "$out" "[syntax]"

# A fixed warning is reported, never a failure
printf 'import QtQuick\nItem { id: box }\n' >"$work/Box.qml"
out=$(sh "$lint" "$work/Box.qml" 2>&1); rc=$?
check "a fixed warning passes" "$rc" 0
has "and asks for --update" "$out" "1 baseline warnings are gone"

# Named files only touch their own entries: another file's stay, and are not
# reported gone by a check of the named files
printf 'import QtQuick\nItem { width: nope }\n' >"$work/Box.qml"
printf '# header\nOther.qml\tunqualified\tUnqualified access\tzap\n' >"$work/baseline.txt"
sh "$lint" --update "$work/Box.qml" >/dev/null 2>&1
check "--update with files keeps the other files' entries" "$(grep -c '^Other.qml' "$work/baseline.txt")" 1
check "and records the named file" "$(grep -c 'Box.qml' "$work/baseline.txt")" 1
out=$(sh "$lint" "$work/Box.qml" 2>&1); rc=$?
check "a check of named files passes" "$rc" 0
check "and does not call the other files' entries gone" "$(printf '%s' "$out" | grep -c 'gone')" 0
sh "$lint" --update "$work/Box.qml" >/dev/null 2>&1
check "a second partial --update does not duplicate entries" "$(grep -vc '^#' "$work/baseline.txt")" 2

QMLLINT=/nonexistent/qmllint sh "$lint" "$work/Box.qml" >/dev/null 2>&1
check "a missing qmllint is not a pass" "$?" 2

[ "$fails" -eq 0 ] && echo "all lint tests passed" || { echo "$fails lint tests failed"; exit 1; }
