#!/bin/sh
# Offscreen QtTest of the settings page with real key events (needs qmltestrunner-qt6).
cd "$(dirname "$0")/../../scripts/preview" || exit 1
TZ=UTC QT_QPA_PLATFORM=offscreen timeout 120 qmltestrunner-qt6 -import imports -input ../../tests/qml-page/tst_searchKeys.qml 2>&1 | grep -E 'FAIL|PASS|Totals|Error|error' 
