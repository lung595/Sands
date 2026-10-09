import QtQuick
import Quickshell.Io
import qs.Services
import "../../TimeParser.js" as TP
import "IpcReplies.js" as Replies

// dms ipc call smartTimer <function> [arguments]
// Only translates a command line into engine calls and their answer into
// a sentence (IpcReplies.js). `engine` is the TimerDaemon.
IpcHandler {
    id: ipc

    required property var engine

    target: "smartTimer"

    // dms ipc call smartTimer start "12 min pâtes"
    function start(text: string): string {
        if (TP.tooLong(text))
            return Replies.tooLong(engine.guideUrl);
        const r = engine.startText(text);
        if (!r)
            return Replies.notUnderstood(engine.guideUrl);
        return Replies.started(r, engine.lastRefusal, engine.maxTimers, engine.guideUrl, engine.use24h());
    }

    // Pauses / resumes the nearest timer; stops the alarm.
    function toggle(): string {
        if (engine.ringing) {
            engine.dismissRinging();
            return "Alarm stopped";
        }
        if (!engine.primary)
            return "No timer";
        engine.toggle(engine.primary.id);
        return "OK";
    }

    function pause(): string {
        engine.timers.filter(t => t.state === "running").forEach(t => engine.pause(t.id));
        return "OK";
    }

    function resume(): string {
        engine.timers.filter(t => t.state === "paused").forEach(t => engine.resume(t.id));
        return "OK";
    }

    // Stops whatever is ringing, otherwise cancels the nearest timer.
    function stop(): string {
        if (engine.ringing) {
            engine.dismissRinging();
            return "Alarm stopped";
        }
        if (!engine.primary)
            return "No timer";
        engine.remove(engine.primary.id);
        return "Timer cancelled";
    }

    // dms ipc call smartTimer add 5  → +5 min on the nearest timer
    function add(minutes: int): string {
        if (!engine.primary)
            return "No timer";
        if (!engine.adjust(engine.primary.id, minutes * 60000))
            return Replies.notChanged(engine.guideUrl);
        return "OK";
    }

    // Bind to a shortcut: opens / closes the panel on the active screen.
    function panel(): string {
        const scr = CompositorService.getFocusedScreen();
        engine.panelRequested(scr ? scr.name : "");
        return "OK";
    }

    function clear(): string {
        engine.clear();
        return "All timers cleared";
    }

    function list(): string {
        return Replies.list(engine.sorted, engine.now);
    }
}
