pragma Singleton
import QtQuick

// Preview stand-in for the DMS path helper
QtObject {
    function strip(url) {
        return String(url).replace(/^file:\/\//, "");
    }
}
