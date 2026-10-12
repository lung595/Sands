#!/bin/sh
# Runs daemon-loop.qml (the whole daemon) offscreen with the real Quickshell,
# until stopped. Nothing touches the session: a throw-away home, no Wayland,
# no session bus, and stand-ins first on PATH for every program that would
# make a sound, show a notification, fill the clipboard or talk to the shell
# (pw-play, paplay, notify-send, wl-copy, dms, niri). The other probes of the
# report (rpm, cat, journalctl, quickshell --version) are the real ones: they
# only read.
#
#   daemon-loop.sh <idle|run|report> [plugin-root]
#
# plugin-root is the revision to load (default: the one this script is in), so
# an older revision can be measured with this very scene. For an A/B bench:
#   banc-ab.sh -s scripts/preview <repo> <refA> <refB> -- sh scripts/preview/daemon-loop.sh idle "$PWD"
# The line "sands-bench ready <mode>" on stderr marks the end of the start-up.
set -eu

mode=${1:-idle}
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "${2:-$here/../..}" && pwd)
# One folder per revision root, rebuilt at each start (nothing piles up)
dir=${SANDS_BENCH_DIR:-${TMPDIR:-/tmp}/sands-daemon-loop-$(id -u)}/$(printf %s "$root" | cksum | cut -d' ' -f1)

rm -rf "$dir"
mkdir -p "$dir/tree" "$dir/bin" "$dir/user/config" "$dir/user/data" "$dir/user/state" "$dir/run"
chmod 700 "$dir/run"

# The plugin as shipped, the stand-ins of the DMS modules, the scene as root
cp "$root"/*.qml "$root"/*.js "$root/plugin.json" "$dir/tree/"
cp -r "$root/components" "$root/diagnostics" "$root/sounds" "$dir/tree/"
cp -r "$here/imports/qs/." "$dir/tree/"
cp "$here/daemon-loop.qml" "$dir/tree/shell.qml"
# The one file that needs a layer shell (never created while nothing rings)
cp "$here/mock/DuneWindows.qml" "$dir/tree/components/alert/DuneWindows.qml"

for tool in pw-play paplay notify-send wl-copy niri; do
    printf '#!/bin/sh\nexit 0\n' > "$dir/bin/$tool"
done
printf '#!/bin/sh\necho "dms bench"\n' > "$dir/bin/dms"
chmod +x "$dir/bin"/*

cd "$dir/tree"
exec env -u WAYLAND_DISPLAY -u NIRI_SOCKET -u DBUS_SESSION_BUS_ADDRESS -u JOURNAL_STREAM \
    HOME="$dir/user" XDG_CONFIG_HOME="$dir/user/config" XDG_DATA_HOME="$dir/user/data" \
    XDG_STATE_HOME="$dir/user/state" XDG_RUNTIME_DIR="$dir/run" \
    PATH="$dir/bin:$PATH" QT_QPA_PLATFORM=offscreen SANDS_BENCH_MODE="$mode" \
    quickshell -p shell.qml
