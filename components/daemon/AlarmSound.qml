import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../../Guide.js" as Guide
import "Sound.js" as Sound

// Everything that makes noise: the repeating alarm, the settings preview and
// the optional tick. One idle `Process` each, started only while a sound
// plays; nothing runs at rest. Which file, how loud and which player come
// from Sound.js. `engine` is the TimerDaemon (settings and explanations).
Item {
    id: sound

    required property var engine

    // The rings shipped with the plugin, as a local path ending with "/".
    readonly property string ringDir: decodeURIComponent(Qt.resolvedUrl("../../sounds/").toString().replace(/^file:\/\//, ""))
    readonly property string tickSound: "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"

    // True from the moment an alarm starts ringing until it is silenced
    property bool active: false

    property real _ringStartedAt: 0
    property int _ringCount: 0
    property bool _useFallbackPlayer: false

    // The file the alarm plays; `choice` and `custom` default to the saved
    // settings, Preview passes what is shown in the settings page.
    function soundPath(choice, custom) {
        return Sound.soundFile(choice === undefined ? engine.setting("sound", "") : choice, custom === undefined ? engine.setting("customSound", "") : custom, Quickshell.env("HOME"), ringDir);
    }

    // "Do not disturb": the pill pulses, but no sound.
    function muted() {
        return engine.setting("respectDnd", true) && SessionData.doNotDisturb;
    }

    // How long an alarm makes noise and moves (the same setting for both).
    function ringLimitMs() {
        return Sound.ringLimitMs(engine.setting("ringDuration", 60));
    }

    function _volume() {
        return Sound.volumeOf(engine.setting("volume", 80));
    }

    function _command(path, volume) {
        return Sound.playerCommand(_useFallbackPlayer, path, volume);
    }

    function startRinging() {
        if (muted())
            return;
        _ringStartedAt = Date.now();
        _ringCount = 0;
        active = true;
        _playOnce();
    }

    function _playOnce() {
        if (!active)
            return;
        ringPlayer.command = _command(soundPath(), _volume() * Sound.ramp(engine.setting("rampUp", true), _ringCount));
        _ringCount++;
        ringPlayer.startedAt = Date.now();
        ringPlayer.running = true;
    }

    // Silences the sound; the timer stays "finished" (the pill pulses) until
    // it is stopped or restarted.
    function silence() {
        active = false;
        ringGap.stop();
        if (ringPlayer.running)
            ringPlayer.running = false;
    }

    // A new preview waits for the previous one to stop, so a player we
    // stopped ourselves is never mistaken for a file that cannot be played.
    function preview(path) {
        previewPlayer.path = path || soundPath();
        if (previewPlayer.running) {
            previewPlayer.next = true;
            previewPlayer.running = false;
        } else {
            _playPreview();
        }
    }

    function _playPreview() {
        previewPlayer.command = _command(previewPlayer.path, _volume());
        previewPlayer.startedAt = Date.now();
        previewPlayer.running = true;
    }

    function playTick() {
        tickPlayer.running = false;
        tickPlayer.command = _command(tickSound, _volume() * 0.35);
        tickPlayer.running = true;
    }

    // Stops every player and timer, for the engine's unloading
    function shutdown() {
        ringGap.stop();
        ringPlayer.running = false;
        previewPlayer.closing = true;
        previewPlayer.running = false;
    }

    Process {
        id: ringPlayer
        property real startedAt: 0
        onExited: (exitCode, exitStatus) => {
            if (!sound.active)
                return;
            // pw-play missing or failing right away: fall back to paplay.
            if (exitCode !== 0 && !sound._useFallbackPlayer && Date.now() - startedAt < 1500) {
                sound._useFallbackPlayer = true;
                sound._playOnce();
                return;
            }
            if (exitCode !== 0) {
                sound.active = false;
                // Both players failed: the file is the problem, so keep
                // pw-play as the first choice next time
                sound._useFallbackPlayer = false;
                sound.engine.explain(Guide.silentNote());
                return;
            }
            if (Date.now() - sound._ringStartedAt >= sound.ringLimitMs()) {
                sound.active = false;
                return;
            }
            ringGap.restart();
        }
    }

    Timer {
        id: ringGap
        interval: 450
        onTriggered: sound._playOnce()
    }

    Process {
        id: previewPlayer
        property string path: ""
        property bool next: false
        property bool closing: false
        property real startedAt: 0
        onExited: (exitCode, exitStatus) => {
            if (next) {
                next = false;
                sound._playPreview();
                return;
            }
            if (exitCode === 0 || closing)
                return;
            // Same fallback as the alarm: pw-play missing or failing at once
            if (!sound._useFallbackPlayer && Date.now() - startedAt < 1500) {
                sound._useFallbackPlayer = true;
                sound._playPreview();
                return;
            }
            sound._useFallbackPlayer = false;
            sound.engine.explain(Guide.previewNote());
        }
    }

    Process {
        id: tickPlayer
    }
}
