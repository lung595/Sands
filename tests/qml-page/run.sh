#!/bin/sh
# Offscreen QtTest of the settings page and the favourites with real clicks and key events (needs qmltestrunner-qt6).
cd "$(dirname "$0")/../../scripts/preview" || exit 1
TZ=UTC QT_QPA_PLATFORM=offscreen timeout 120 qmltestrunner-qt6 -import imports -input ../../tests/qml-page > "${TMPDIR:-/tmp}/sands-page-test.out" 2>&1
status=$?
grep -E 'FAIL|PASS|Totals|Error|error' "${TMPDIR:-/tmp}/sands-page-test.out"
exit $status
