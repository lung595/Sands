#!/bin/sh
# Offscreen QML tests with the real Quickshell, on a throw-away folder. The
# component is staged next to the test so Quickshell does not scan the whole
# components folder (it would try to resolve the DMS imports of its neighbours).
here=$(cd "$(dirname "$0")" && pwd)
for t in "$here"/tst_*.qml; do
  HS_TMP=$(mktemp -d)
  cp "$t" "$here/../../components/daemon/HistoryStore.qml" "$here/../../components/daemon/History.js" "$HS_TMP/"
  out=$(cd "$HS_TMP" && HS_TMP=$HS_TMP QT_QPA_PLATFORM=offscreen timeout 60 quickshell -p "$(basename "$t")" 2>&1)
  rm -rf "$HS_TMP"
  echo "$out" | grep -q 'qml.*PASS' && echo "ok $(basename "$t")" || { echo "FAIL $(basename "$t")"; echo "$out" | tail -12; exit 1; }
done
