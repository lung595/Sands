#!/bin/sh
# Offscreen QtTest of the Rising dune band (needs qmltestrunner-qt6).
cd "$(dirname "$0")/../../scripts/preview" || exit 1
out=$(mktemp)
QT_QPA_PLATFORM=offscreen timeout 120 qmltestrunner-qt6 -import imports -input ../../tests/qml-dune/tst_duneBand.qml > "$out" 2>&1
status=$?
grep -E 'FAIL|PASS|Totals|Error|error' "$out"
rm -f "$out"
exit $status
