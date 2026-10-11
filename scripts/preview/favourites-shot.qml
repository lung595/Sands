import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/favourites"

// Renders the pinned favourites at the panel width to a picture, from made-up history.
// Usage: QT_QPA_PLATFORM=offscreen qml-qt6 -I imports favourites-shot.qml -- <glasses|rows> <started|long|plain> <width> <out.png> [light] [reduce]
// ("light" and "reduce" among the arguments switch the stand-in Theme and SettingsData)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property int argBase: args.indexOf("--") + 1
    readonly property string look: args[argBase]
    readonly property string scene: args[argBase + 1]

    width: parseInt(args[argBase + 2])
    height: fav.height + 2 * Theme.spacingM
    visible: true
    color: Theme.surface

    QtObject {
        id: fakeDaemon
        function historyFavourites(done) {
            const names = win.scene === "long" ? "a very long name that cannot possibly fit" : "work";
            done([
                {
                    name: names,
                    count: 41,
                    ms: 25 * 60000
                },
                {
                    name: "tea",
                    count: 23,
                    ms: 4 * 60000
                },
                {
                    name: "pasta",
                    count: 17,
                    ms: 11 * 60000
                }
            ]);
        }
        function start() {
            return 1;
        }
    }

    // The picture is taken from the content item, which has no window colour
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Favourites {
        id: fav
        y: Theme.spacingM
        daemon: fakeDaemon
        lookKey: win.look
        Component.onCompleted: if (win.scene === "started")
            startPin(1)
    }

    Timer {
        interval: 600
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.args[win.argBase + 3]);
            Qt.quit();
        })
    }
}
