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
  # "fakebin" puts stand-ins for wl-copy and dms first on PATH: they record
  # their arguments and their standard input in $QML_TMP, and wl-copy is
  # "not installed" (exit 127) while $QML_TMP/no-wl exists
  fakepath=$PATH
  if grep -q '^// fakebin' "$t"; then
    mkdir "$QML_TMP/bin"
    cat > "$QML_TMP/bin/wl-copy" <<'FAKE'
#!/bin/sh
[ -e "$QML_TMP/no-wl" ] && exit 127
echo "$*" > "$QML_TMP/wl.argv"
cat > "$QML_TMP/wl.stdin"
FAKE
    cat > "$QML_TMP/bin/dms" <<'FAKE'
#!/bin/sh
echo "$*" > "$QML_TMP/dms.argv"
case "$1" in version) echo "dms v1.6.3" ;; *) cat > "$QML_TMP/dms.stdin" ;; esac
FAKE
    chmod +x "$QML_TMP/bin/wl-copy" "$QML_TMP/bin/dms"
    fakepath="$QML_TMP/bin:$PATH"
  fi
  out=$(cd "$QML_TMP" && PATH=$fakepath QML_TMP=$QML_TMP QT_QPA_PLATFORM=offscreen timeout 60 quickshell -p "$test_file" 2>&1)
  rm -rf "$QML_TMP"
  echo "$out" | grep -q 'qml.*PASS' && echo "ok $(basename "$t")" || { echo "FAIL $(basename "$t")"; echo "$out" | tail -12; exit 1; }
done
