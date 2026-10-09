pragma Singleton
import QtQuick

// Preview stand-in: a fixed home and no detached command, so nothing leaves
// the offscreen scene.
QtObject {
    function env(name) {
        return name === "HOME" ? "/nonexistent" : "";
    }
    function execDetached(command) {
    }
}
