#!/bin/sh
# End-to-end test of the real daemon, offscreen with the real Quickshell (about
# 20 s). Staged like scripts/preview/daemon-loop.sh: the plugin as shipped, the
# stand-ins of the DMS modules, a throw-away home, no Wayland, no session bus,
# and stand-ins first on PATH for every program the daemon may run. Each one
# records its arguments, so check.js can assert what the end of a timer did.
#   1. ring:    a 2 s timer rings: sound, dune, notification, saved state,
#               journal; the old end-mode and end-action settings are
#               dropped at start, with one toast for the end actions
#   (an 8 s timer then ends between the two runs, while no shell runs)
#   2. restore: a new daemon from that saved state: the timers come back, both
#               ended ones ring and are notified again; each stop closes its
#               notification, the last one (the dune's click) silences the
#               alarm and takes the dune down; Rice's old end action is
#               dropped and nothing is told again
#   3. mute:    a muted timer rings without sound (dune and notification only),
#               rename drops emoji, a stopped timer comes back within 5 s and
#               not after, pause all / resume all, one list change per action
# Exit 1 on any failure, with the reasons, or on any script error in the logs.
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
preview=$root/scripts/preview
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

mkdir -p "$dir/tree" "$dir/bin" "$dir/user/config" "$dir/user/data" "$dir/user/state" "$dir/run" "$dir/log"
chmod 700 "$dir/run"
cp "$root"/*.qml "$root"/*.js "$root/plugin.json" "$dir/tree/"
cp -r "$root/components" "$root/diagnostics" "$root/sounds" "$dir/tree/"
cp -r "$preview/imports/qs/." "$dir/tree/"
cp "$here/shell.qml" "$dir/tree/shell.qml"
# One output, not muted: what the alarm checks before it rings
cp "$here/AudioService.qml" "$dir/tree/Services/AudioService.qml"
echo "singleton AudioService 1.0 AudioService.qml" >> "$dir/tree/Services/qmldir"
# The dune needs a layer shell, which no offscreen run has
cp "$preview/mock/DuneWindows.qml" "$dir/tree/components/alert/DuneWindows.qml"

# One line per call: epoch ms, tool, then each argument, tab-separated
cat > "$dir/bin/record" <<'FAKE'
#!/bin/sh
tool=$1; shift
line="$(date +%s%3N)	$tool"
for a in "$@"; do line="$line	$a"; done
printf '%s\n' "$line" >> "$E2E_DIR/log/calls.tsv"
FAKE
# pw-play: a one-second ring
printf '#!/bin/sh\n"$E2E_DIR/bin/record" pw-play "$@"\nexec sleep 1\n' > "$dir/bin/pw-play"
# notify-send -p: prints its id, then stays until gdbus closes that
# notification or the shell is gone. Fixed ids, so two notifications started
# together never race: 41 for the ring run, then 42 (Tea) and 43 (Rice)
cat > "$dir/bin/notify-send" <<'FAKE'
#!/bin/sh
"$E2E_DIR/bin/record" notify-send "$@"
n=41
[ "$SANDS_E2E_PHASE" = restore ] && n=42
case "$*" in *"Rice - done"*) n=43 ;; esac
echo "$n"
while [ ! -e "$E2E_DIR/log/closed-$n" ] && kill -0 "$PPID" 2>/dev/null; do sleep 0.1; done
FAKE
# gdbus: closing a notification ends its notify-send
cat > "$dir/bin/gdbus" <<'FAKE'
#!/bin/sh
"$E2E_DIR/bin/record" gdbus "$@"
for last; do :; done
touch "$E2E_DIR/log/closed-$last"
FAKE
# systemctl and playerctl: an old end action must never run
for tool in paplay wl-copy niri dms systemctl playerctl; do
    printf '#!/bin/sh\n"$E2E_DIR/bin/record" %s "$@"\n' "$tool" > "$dir/bin/$tool"
done
chmod +x "$dir/bin"/*

# phase <name> <state json>: one daemon run, its "sands-e2e" lines kept
phase() {
    (cd "$dir/tree" && env -u WAYLAND_DISPLAY -u NIRI_SOCKET -u DBUS_SESSION_BUS_ADDRESS -u JOURNAL_STREAM \
        HOME="$dir/user" XDG_CONFIG_HOME="$dir/user/config" XDG_DATA_HOME="$dir/user/data" \
        XDG_STATE_HOME="$dir/user/state" XDG_RUNTIME_DIR="$dir/run" \
        PATH="$dir/bin:$PATH" QT_QPA_PLATFORM=offscreen E2E_DIR="$dir" LC_ALL=en_US.UTF-8 \
        SANDS_E2E_PHASE="$1" SANDS_E2E_STATE="$2" \
        timeout 25 quickshell -p shell.qml > "$dir/log/$1.out" 2>&1)
    sed -n 's/.*sands-e2e //p' "$dir/log/$1.out" > "$dir/log/$1.lines"
    : >> "$dir/log/calls.tsv"
    mv "$dir/log/calls.tsv" "$dir/log/$1.calls"
}

phase ring '{}'
state=$(gjs -m "$here/check.js" state "$dir") || { tail -20 "$dir/log/ring.out"; exit 1; }
# The journal as the first daemon left it, before the second one runs
cp "$dir/user/state/sands/history.json" "$dir/log/ring.history" 2>/dev/null
stat -c '%a' "$dir/user/state/sands" "$dir/user/state/sands/history.json" > "$dir/log/modes" 2>/dev/null
# Rice must end while no daemon runs
sleep "$(gjs -m "$here/check.js" wait "$dir")"
phase restore "$state"
cp "$dir/user/state/sands/history.json" "$dir/log/restore.history" 2>/dev/null
phase mute '{}'
gjs -m "$here/check.js" verify "$dir" || { echo "--- ring"; tail -15 "$dir/log/ring.out"; echo "--- restore"; tail -15 "$dir/log/restore.out"; echo "--- mute"; tail -15 "$dir/log/mute.out"; exit 1; }
