import QtQuick
import Quickshell.Io
import qs.Services
import "../../TimeParser.js" as TP
import "../../diagnostics/Gather.js" as Gather
import "IpcReplies.js" as Replies
import "Snooze.js" as Snooze
import "Status.js" as Status

// dms ipc call smartTimer <function> [arguments]
// Only translates a command line into engine calls and their answer into
// a sentence (IpcReplies.js). `engine` is the TimerDaemon.
IpcHandler {
    id: ipc

    required property var engine
    // The ReportService
    required property var report

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

    // dms ipc call smartTimer snooze <minutes>: restarts the first ringing
    // timer for that long; 0 uses the default snooze. Quickshell has no
    // optional IPC arguments, so the length cannot be left out. JSON answer.
    function snooze(minutes: int): string {
        const ringing = engine.sorted.find(t => t.state === "ringing");
        if (!ringing)
            return Replies.notRinging();
        const m = Snooze.forIpc(minutes);
        // Cannot fail: 1..120 min is always inside adjust's range for a ringing timer
        engine.adjust(ringing.id, Snooze.toMs(m));
        return Replies.snoozed(m);
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

    // JSON for scripts: timers, remaining seconds, phase. Built on call only.
    function status(): string {
        return Status.build(engine.sorted, engine.now);
    }

    // dms ipc call smartTimer diagnostics: the first call starts the anonymous
    // report, the next one (a couple of seconds later) hands it over, once.
    // Nothing is measured unless this is called, and no argument is read.
    function diagnostics(): string {
        if (report.report)
            return Gather.capped(report.takeReport());
        if (report.busy)
            return Replies.stillCollecting(engine.guideUrl);
        report.request("ipc");
        return Replies.collecting(engine.guideUrl);
    }
}
