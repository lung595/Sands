#!/bin/sh
# Offscreen QML tests with the real Quickshell, on a throw-away folder. Each test
# is staged with the component files it needs (listed in the test header as
# "needs:") so Quickshell does not scan the whole components folder (it would try
# to resolve the DMS imports of its neighbours).
here=$(cd "$(dirname "$0")" && pwd)
for t in "$here"/tst_*.qml; do
  QML_TMP=$(mktemp -d)
  cp "$t" "$QML_TMP/"
  for f in $(sed -n 's|^// needs: ||p' "$t"); do cp "$here/../../$f" "$QML_TMP/"; done
  out=$(cd "$QML_TMP" && QML_TMP=$QML_TMP QT_QPA_PLATFORM=offscreen timeout 60 quickshell -p "$(basename "$t")" 2>&1)
  rm -rf "$QML_TMP"
  echo "$out" | grep -q 'qml.*PASS' && echo "ok $(basename "$t")" || { echo "FAIL $(basename "$t")"; echo "$out" | tail -12; exit 1; }
done
