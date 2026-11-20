pragma Singleton
import QtQuick

// Preview stand-in: nothing is drawn offscreen; every toast is kept in
// `shown` ({ message, level }) for the tests to read
QtObject {
    readonly property int levelInfo: 0
    readonly property int levelWarn: 1
    readonly property int levelError: 2
    property var shown: []

    function showToast(message, level, details, command, category) {
        shown = shown.concat([{
                "message": message,
                "level": level === undefined ? levelInfo : level
            }]);
    }
    function showError(message, details) {
        showToast(message, levelError, details);
    }
}
