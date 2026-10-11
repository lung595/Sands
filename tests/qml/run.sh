#!/bin/sh
# Offscreen QML tests with the real Quickshell, on a throw-away folder. Each test
# is staged with the component files it needs (listed in the test header as
# "needs:") so Quickshell does not scan the whole components folder (it would try
# to resolve the DMS imports of its neighbours).
here=$(cd "$(dirname "$0")" && pwd)
for t in "$here"/tst_*.qml; do
  QML_TMP=$(mktemp -d)
  # "layout: tree" keeps the plugin folders (components/alert/ next to
  # components/daemon/) for components that import a sibling folder by relative
  # path (Quickshell blocks files outside its root); the test becomes the root
  # shell.qml and imports "components/alert" itself. Default: everything flat.
  if grep -q '^// layout: tree' "$t"; then
    for f in $(sed -n 's|^// needs: ||p' "$t"); do (cd "$here/../.." && cp --parents "$f" "$QML_TMP/"); done
    cp "$t" "$QML_TMP/shell.qml"; test_file=shell.qml
  else
    for f in $(sed -n 's|^// needs: ||p' "$t"); do cp "$here/../../$f" "$QML_TMP/"; done
    cp "$t" "$QML_TMP/"; test_file=$(basename "$t")
  fi
  # "stubs: qs" stages the preview stand-ins of the DMS modules (qs.Common...)
  grep -q '^// stubs: qs' "$t" && cp -r "$here/../../scripts/preview/imports/qs/." "$QML_TMP/"
  out=$(cd "$QML_TMP" && QML_TMP=$QML_TMP QT_QPA_PLATFORM=offscreen timeout 60 quickshell -p "$test_file" 2>&1)
  rm -rf "$QML_TMP"
  echo "$out" | grep -q 'qml.*PASS' && echo "ok $(basename "$t")" || { echo "FAIL $(basename "$t")"; echo "$out" | tail -12; exit 1; }
done
