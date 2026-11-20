#!/bin/sh
# Test of tests/run-all.sh on a made-up tree (only run-all.sh is copied, the
# tests are fakes): a failure does not stop the run, the recap names every job
# with ok/FAIL, the exit code says whether one failed, the runners run side by
# side in their own TMPDIR, --fast leaves them out, and new files are found by
# their names alone. Run: sh tests/run-all.test.sh
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
check() {
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got $2, want $3)"; fails=$((fails + 1)); fi
}
has() {
    if printf '%s\n' "$2" | grep -qE -- "$3"; then echo "ok   $1"; else echo "FAIL $1: no /$3/ in"; printf '%s\n' "$2"; fails=$((fails + 1)); fi
}
hasnt() {
    if printf '%s\n' "$2" | grep -qE -- "$3"; then echo "FAIL $1: /$3/ in"; printf '%s\n' "$2"; fails=$((fails + 1)); else echo "ok   $1"; fi
}

mkdir -p "$work/tests/qml-a" "$work/tests/qml-b"
cp "$here/run-all.sh" "$work/tests/"
printf 'print("fine");\n' > "$work/tests/a.test.js"
printf 'print("broken a"); imports.system.exit(3);\n' > "$work/tests/b.test.js"
printf 'print("fine too");\n' > "$work/tests/c.test.js"
printf 'echo fine\n' > "$work/tests/d.test.sh"
# Two runners that each leave a mark and wait up to 3 s for the other's: they
# only both get past it when they run side by side. b then fails on purpose.
cat > "$work/tests/qml-a/run.sh" <<'RUNNER'
touch "$WORK/a"; i=0
while [ ! -e "$WORK/b" ] && [ $i -lt 30 ]; do sleep 0.1; i=$((i + 1)); done
[ -e "$WORK/b" ] && echo "runner a"
RUNNER
cat > "$work/tests/qml-b/run.sh" <<'RUNNER'
touch "$WORK/b"; i=0
while [ ! -e "$WORK/a" ] && [ $i -lt 30 ]; do sleep 0.1; i=$((i + 1)); done
[ -e "$WORK/a" ] || exit 1
echo "runner b in $TMPDIR" > "$TMPDIR/out"; cat "$TMPDIR/out"; exit 4
RUNNER
export WORK="$work"

out=$(sh "$work/tests/run-all.sh" --fast 2>&1); status=$?
check "fast: exit 1 when one fails" "$status" 1
has "fast: the failure is named with its exit code" "$out" "=== FAIL b.test.js \(exit 3\)"
has "fast: the output of the failed job" "$out" "broken a"
has "fast: a job after the failure still runs" "$out" "^c.test.js +ok +[0-9]+\.[0-9]$"
has "fast: sh tests run" "$out" "^d.test.sh +ok"
has "fast: recap line of the failure" "$out" "^b.test.js +FAIL"
has "fast: count" "$out" "^1 of 4 failed$"
hasnt "fast: no runner" "$out" "qml-a"

out=$(sh "$work/tests/run-all.sh" 2>&1); status=$?
check "full: exit 1" "$status" 1
has "full: runners found by name, side by side" "$out" "^qml-a/run.sh +ok"
has "full: each runner in its own TMPDIR" "$out" "^runner b in /[^ ]+/[0-9]+\.tmp$"
has "full: a failed runner in the recap" "$out" "^qml-b/run.sh +FAIL"
has "full: its exit code" "$out" "=== FAIL qml-b/run.sh \(exit 4\)"
has "full: count" "$out" "^2 of 6 failed$"
hasnt "full: no lint without scripts/lint.sh" "$out" "^lint "

rm "$work/tests/b.test.js" "$work/tests/qml-b/run.sh" "$work/a" "$work/b"
out=$(sh "$work/tests/run-all.sh" 2>&1); status=$?
check "a runner alone: exit 1" "$status" 1
has "a runner alone waits in vain" "$out" "^qml-a/run.sh +FAIL"
rm "$work/tests/qml-a/run.sh"
out=$(sh "$work/tests/run-all.sh" 2>&1); status=$?
check "all green: exit 0" "$status" 0
has "all green: summary" "$out" "^all 3 passed$"

out=$(sh "$work/tests/run-all.sh" --nope 2>&1); status=$?
check "unknown option: exit 2" "$status" 2

[ $fails -eq 0 ] && echo "run-all: all checks passed" || { echo "run-all: $fails failed"; exit 1; }
