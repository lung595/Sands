import QtQuick
import "../.."

// Offscreen check of the launcher provider: prints what each query would show
// (name, comment) from made-up input. No window, nothing of the live shell is read.
// Usage: TZ=UTC QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml-qt6 -I imports launcher.qml
Item {
    TimerLauncher {
        id: launcher
    }

    Component.onCompleted: {
        ["pasta 12", "timer 12 min pasta", "wake up at 7am", "1h30", "14h30 run", "3 x 12 min eggs", "zzzz", "timer blorp"].forEach(q => {
            const items = launcher.getItems(q);
            console.warn("> " + q + (items.length === 0 ? "  (no item)" : ""));
            items.forEach(i => console.warn("    " + i.name + "   |   " + i.comment));
        });
        Qt.quit();
    }
}
