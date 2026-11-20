#!/bin/sh
# Every test of the plugin in one command, with a recap at the end.
#
#   sh tests/run-all.sh          # full: fast set plus every offscreen QML run and the lint, about 1 min
#   sh tests/run-all.sh --fast   # gjs and sh tests only, a few seconds
#
# Fast: every tests/*.test.js (gjs) and tests/*.test.sh (sh), one after the
# other. Full adds, in parallel with them: every tests/*/run.sh (the QML
# runners, the daemon end to end), tests/journal-layout.sh, the settings
# overlap scene, the Alex bridge scene while it exists, and scripts/lint.sh.
# New files that follow these names are picked up without editing this script.
#
# A failure never stops the run: each job writes to its own temporary file
# (and gets its own TMPDIR), the end of a failed job's output is printed, then
# a table of every job (name, ok/FAIL, seconds). Exit 1 if any job failed.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
full=1
case "${1:-}" in
    --fast) full=0 ;;
    "") ;;
    *) echo "usage: sh tests/run-all.sh [--fast]" >&2; exit 2 ;;
esac

work=$(mktemp -d)
pids=""
trap 'rm -rf "$work"' EXIT
trap 'for p in $pids; do kill "$p" 2>/dev/null; done; exit 130' INT TERM
n=0

# job <name> <command...>: runs the command (a program or a function below)
# from the repository root, output to $work/<n>.out, then "<status>
# <milliseconds>" to $work/<n>.res. bg <name> <command...>: the same in the
# background. The number is taken here, in this shell, never in a subshell.
job() {
    n=$((n + 1))
    printf '%s\n' "$1" > "$work/$n.name"
    mkdir "$work/$n.tmp"
    run "$n" "$@"
}
bg() {
    n=$((n + 1))
    printf '%s\n' "$1" > "$work/$n.name"
    mkdir "$work/$n.tmp"
    run "$n" "$@" &
    pids="$pids $!"
}
run() (
    i=$1; shift 2
    cd "$root" || exit 2
    export TMPDIR="$work/$i.tmp"
    start=$(date +%s%N)
    "$@" > "$work/$i.out" 2>&1
    status=$?
    echo "$status $(( ($(date +%s%N) - start) / 1000000 ))" > "$work/$i.res"
)

# The Alex bridge scene loads the real daemon, so it runs on a copy of the
# plugin with the stand-in of the dune windows (no layer shell offscreen), and
# must print "OK present" and "OK absent"
alex() {
    tree=$TMPDIR/tree
    mkdir -p "$tree/scripts"
    cp ./*.qml ./*.js plugin.json "$tree/" && cp -r components diagnostics sounds "$tree/" &&
        cp -r scripts/preview "$tree/scripts/" &&
        cp scripts/preview/mock/DuneWindows.qml "$tree/components/alert/DuneWindows.qml" || return 1
    cd "$tree/scripts/preview" || return 1
    fails=0
    for mode in present absent; do
        out=$(QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 60 qml-qt6 -I imports alex.qml -- "$mode" /dev/null 2>&1)
        status=$?
        printf '%s\n' "$out"
        [ $status -eq 0 ] && printf '%s\n' "$out" | grep -q "OK $mode" || { echo "FAIL alex $mode (exit $status)"; fails=1; }
    done
    return $fails
}

overlap() {
    cd scripts/preview && TZ=UTC QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 120 qml-qt6 -I imports settings-overlap.qml
}

cd "$root" || exit 2
if [ $full -eq 1 ]; then
    for r in tests/*/run.sh; do
        [ -f "$r" ] && bg "${r#tests/}" sh "$r"
    done
    [ -f tests/journal-layout.sh ] && bg journal-layout.sh sh tests/journal-layout.sh
    [ -f scripts/preview/settings-overlap.qml ] && bg settings-overlap overlap
    [ -f scripts/preview/alex.qml ] && bg alex.qml alex
    [ -f scripts/lint.sh ] && bg lint sh scripts/lint.sh
fi
for t in tests/*.test.js; do [ -f "$t" ] && job "${t#tests/}" gjs "$t"; done
for t in tests/*.test.sh; do [ -f "$t" ] && job "${t#tests/}" sh "$t"; done
wait

failed=0
i=1
while [ $i -le $n ]; do
    status=1
    [ -f "$work/$i.res" ] && read -r status ms < "$work/$i.res"
    if [ "$status" -ne 0 ]; then
        failed=$((failed + 1))
        echo "=== FAIL $(cat "$work/$i.name") (exit $status), last lines:"
        tail -25 "$work/$i.out"
        echo
    fi
    i=$((i + 1))
done

printf '%-28s %-5s %7s\n' test result seconds
i=1
while [ $i -le $n ]; do
    status=1 ms=0
    [ -f "$work/$i.res" ] && read -r status ms < "$work/$i.res"
    [ "$status" -eq 0 ] && result=ok || result=FAIL
    printf '%-28s %-5s %7s\n' "$(cat "$work/$i.name")" "$result" "$(awk "BEGIN { printf \"%.1f\", $ms / 1000 }")"
    i=$((i + 1))
done
if [ $failed -gt 0 ]; then
    echo "$failed of $n failed"
    exit 1
fi
echo "all $n passed"
