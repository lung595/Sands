#!/bin/sh
# Offscreen QtTest of the settings page (keys, sections, alert rows) and the favourites with real clicks and key events (needs qmltestrunner-qt6).
cd "$(dirname "$0")/../../scripts/preview" || exit 1
out=$(mktemp)
TZ=UTC QT_QPA_PLATFORM=offscreen timeout 120 qmltestrunner-qt6 -import imports -input ../../tests/qml-page > "$out" 2>&1
status=$?
grep -E 'FAIL|PASS|Totals|Error|error' "$out"
rm -f "$out"
exit $status
