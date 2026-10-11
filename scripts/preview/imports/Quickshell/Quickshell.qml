pragma Singleton
import QtQuick

// Preview stand-in: a fixed home and no detached command, so nothing leaves
// the offscreen scene.
QtObject {
    // No screen offscreen; a test hands its own list to the row that needs one
    readonly property var screens: []
    function env(name) {
        return name === "HOME" ? "/nonexistent" : "";
    }
    function execDetached(command) {
    }
}
