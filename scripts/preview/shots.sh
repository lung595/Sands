#!/bin/sh
# Renders every scene of shot.qml to <out dir>/<scene>.png (default: ./out).
#   scripts/preview/shots.sh [out dir] [scene...]
# Offscreen, from made-up timers: nothing of the live shell is read or touched.
# The scenes are listed once, in manifest.txt (name, tolerance, hash), which cmp.sh uses too.
out=$(realpath -m "${1:-out}"); mkdir -p "$out"
cd "$(dirname "$0")" || exit 1
[ $# -gt 0 ] && shift
scenes="${*:-$(cut -d" " -f1 manifest.txt)}"
# UTC and a frozen clock: the "ends at" time of the panel never depends on
# the machine that renders it.
export TZ=UTC QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1
for s in $scenes; do
  timeout 40 qml-qt6 -I imports shot.qml -- "$s" "$out/$s.png" >"$out/$s.log" 2>&1 || echo "FAIL $s"
  [ -s "$out/$s.png" ] || echo "NO PICTURE $s"
done
# Any message from Qt is a sign of a broken stand-in or a changed component
grep -l . "$out"/*.log 2>/dev/null | sed 's/^/LOG /'
