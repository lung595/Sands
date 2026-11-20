pragma Singleton
import QtQuick

// Preview stand-in: errors are not shown offscreen; the last info toast is
// kept for the tests ([message, details, command])
QtObject {
    property var lastInfo: null
    function showError(message, details) {
    }
    function showInfo(message, details, command) {
        lastInfo = [message, details || "", command || ""];
    }
}
