pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Notifications.js" as Notifications

// The end-of-timer notification with Stop / +5 min buttons (useful in
// fullscreen, with the bar hidden). One notify-send process per ringing
// timer, started when it rings and gone when the notification is closed;
// nothing runs at rest. The engine decides what the buttons do.
Item {
    id: notifier

    // The timer's buttons, forwarded to the engine
    signal stopRequested(int timerId)
    signal snoozeRequested(int timerId)

    // timer id → { proc, notifId }
    property var _notifiers: ({})

    function has(timerId) {
        return !!_notifiers[timerId];
    }

    // `bodyText` and `label` come from the engine (settings, clock format)
    function show(t, label, bodyText) {
        if (has(t.id))
            return;
        const proc = notifierComp.createObject(notifier, {
            timerId: t.id,
            command: Notifications.showCommand(label, bodyText)
        });
        const map = Object.assign({}, _notifiers);
        map[t.id] = {
            proc: proc,
            notifId: 0
        };
        _notifiers = map;
        proc.running = true;
    }

    // Closes the notifications of timers that are no longer ringing.
    function sync(list) {
        for (const key in _notifiers) {
            const id = parseInt(key);
            const t = list.find(x => x.id === id);
            if (t && t.state === "ringing")
                continue;
            const n = _notifiers[key];
            if (n.notifId > 0)
                Quickshell.execDetached(Notifications.closeCommand(n.notifId));
            const map = Object.assign({}, _notifiers);
            delete map[key];
            _notifiers = map;
        }
    }

    Component {
        id: notifierComp

        Process {
            id: proc
            property int timerId: 0

            stdout: SplitParser {
                onRead: line => {
                    const r = Notifications.parseLine(line);
                    if (!r)
                        return;
                    if (r.id !== undefined) {
                        const n = notifier._notifiers[proc.timerId];
                        if (n)
                            n.notifId = r.id;
                    } else if (r.action === "stop") {
                        notifier.stopRequested(proc.timerId);
                    } else {
                        notifier.snoozeRequested(proc.timerId);
                    }
                }
            }

            onExited: {
                const map = Object.assign({}, notifier._notifiers);
                if (map[proc.timerId] && map[proc.timerId].proc === proc) {
                    delete map[proc.timerId];
                    notifier._notifiers = map;
                }
                proc.destroy();
            }
        }
    }
}
