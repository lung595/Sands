#!/bin/sh
# Test of scripts/diagnose.sh with made-up tools and a made-up home folder:
# the first IPC call starts the report and the second hands it over; whatever
# personal the shell, the journal or a crash folder holds is reduced; without
# the plugin's answer the script still prints a report. Run: sh tests/diagnose.test.sh
here=$(cd "$(dirname "$0")" && pwd)
script=$(dirname "$here")/scripts/diagnose.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0
# The folder that holds personal folders, written in two parts on purpose
homes=home
check() {
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got $2, want $3)"; fails=$((fails + 1)); fi
}

mkdir -p "$work/bin" "$work/$homes/bobby/.cache/quickshell/crashes/old" "$work/$homes/bobby/.cache/quickshell/crashes/new"
echo "crash at /$homes/bobby/.config/quickshell on bobs-pc" >"$work/$homes/bobby/.cache/quickshell/crashes/new/metadata"
touch -d '2026-01-01' "$work/$homes/bobby/.cache/quickshell/crashes/old"
# A shell that answers on the second call, as the plugin does
cat >"$work/bin/dms" <<'SH'
#!/bin/sh
state="$(dirname "$0")/calls"
n=$(cat "$state" 2>/dev/null || echo 0)
echo $((n + 1)) >"$state"
[ "$1 $2" = "ipc call" ] || { echo "dms v1.6.3"; exit 0; }
if [ "$n" -eq 0 ]; then echo "Collecting (about 2 s): run the same command again"; else
    echo "Sands diagnostic report (anonymous)"
    echo "  12:00:00 SND-E001 action=start reason=limit"
    echo "  journal: failed at /${HOMES}/bobby/.cache/x for AA:BB:CC:DD:EE:01 192.168.7.23"
fi
SH
cat >"$work/bin/id" <<'SH'
#!/bin/sh
echo bobby
SH
cat >"$work/bin/hostname" <<'SH'
#!/bin/sh
echo bobs-pc
SH
chmod +x "$work/bin/dms" "$work/bin/id" "$work/bin/hostname"

out=$(HOMES="$homes" HOME="$work/$homes/bobby" PATH="$work/bin:$PATH" sh "$script" 2>&1)
check "the plugin's report is printed" "$(echo "$out" | grep -c 'SND-E001 action=start')" 1
check "the first call only started it: its answer is not printed" "$(echo "$out" | grep -c 'Collecting')" 0
check "the crash folder is read: the latest one, reduced" "$(echo "$out" | grep -c 'crash at ~/.config/quickshell on host')" 1
check "no login, host name, home path, address in the output" "$(echo "$out" | grep -ciE "bobby|bobs-pc|/$homes/|AA:BB|192\.168")" 0

# No plugin answer: the report is still made, from the command line
cat >"$work/bin/dms" <<'SH'
#!/bin/sh
[ "$1" = "version" ] && { echo "dms v1.6.3"; exit 0; }
exit 1
SH
out=$(HOMES="$homes" HOME="$work/$homes/bobby" PATH="$work/bin:$PATH" sh "$script" 2>&1)
check "without the plugin the fallback report says so" "$(echo "$out" | grep -c 'the plugin did not answer')" 1
check "the fallback holds the DMS version" "$(echo "$out" | grep -c 'DMS          : dms v1.6.3')" 1
check "the fallback leaks nothing either" "$(echo "$out" | grep -ciE "bobby|bobs-pc|/$homes/")" 0

# A host name is text, not a pattern: "." is a dot and "/" or "&" cannot bend the filter
mkdir -p "$work/odd"
cat >"$work/odd/hostname" <<'SH'
#!/bin/sh
echo 'a.b/c&d'
SH
cat >"$work/odd/dms" <<'SH'
#!/bin/sh
[ "$1" = "version" ] && { echo "dms v1.6.3 on a.b/c&d, not aXb/c&d"; exit 0; }
exit 1
SH
chmod +x "$work/odd/hostname" "$work/odd/dms"
out=$(HOMES="$homes" HOME="$work/$homes/bobby" PATH="$work/odd:$work/bin:$PATH" sh "$script" 2>&1)
check "an odd host name is hidden as written" "$(echo "$out" | grep -c 'dms v1.6.3 on host, not aXb/c&d')" 1

[ "$fails" -eq 0 ] && echo "diagnose.sh: all passed" || exit 1
