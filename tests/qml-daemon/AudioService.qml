pragma Singleton
import QtQuick

// Stand-in of the DMS AudioService for the daemon end to end: one output,
// not muted, so the alarm is meant to be heard (RingAlert's _soundState)
QtObject {
    readonly property var sink: ({
            audio: {
                muted: false,
                volume: 0.8
            }
        })
}
