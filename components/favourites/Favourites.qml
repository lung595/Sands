pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "Pins.js" as Pins
import "../settings/Variants.js" as Variants

// Pinned favourites: the three most started timers, one click to start one
// again. Reads the history once, when the panel opens, and draws it with
// the look chosen in the settings (one Loader, only one view exists).
Column {
    id: root

    property var daemon: null
    // False while the panel is closed: nothing is read, nothing is drawn
    property bool shown: true
    // True while another screen of the panel (the journal) covers this one
    property bool covered: false
    property string lookKey: Variants.defaultOf("favourites")
    readonly property string look: Variants.clean("favourites", lookKey)
    readonly property bool reducedMotion: SettingsData.reduceMotion

    // [{ name, ms, duration, count, startedText, label }], at most three
    property var pins: []
    // Index of the pin just started, -1 before any click
    property int startedIndex: -1

    function reload() {
        startedIndex = -1;
        if (!daemon || !daemon.historyFavourites) {
            pins = [];
            return;
        }
        daemon.historyFavourites(list => root.pins = Pins.pins(list));
    }

    // The tile only says "Started" when the daemon really started a timer
    // (it answers -1 on a refusal: limit reached, duration out of range)
    function startPin(index) {
        const p = pins[index];
        if (!p || startedIndex === index || !daemon)
            return;
        if (daemon.start(p.ms, p.name, "duration") !== -1)
            startedIndex = index;
    }

    onShownChanged: if (shown)
        reload()
    Component.onCompleted: if (shown)
        reload()

    width: parent ? parent.width : 340
    spacing: Theme.spacingM
    visible: shown && !covered

    StyledText {
        x: Theme.spacingM
        text: "Most started"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    StyledText {
        visible: root.pins.length === 0
        x: Theme.spacingM
        width: parent.width - 2 * Theme.spacingM
        text: Pins.EMPTY_TEXT
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Loader {
        width: parent.width
        active: root.shown && !root.covered && root.pins.length > 0
        visible: active
        sourceComponent: root.look === "rows" ? rowsView : glassesView
    }

    Component {
        id: glassesView
        Glasses {
            pins: root.pins
            startedIndex: root.startedIndex
            reducedMotion: root.reducedMotion
            onChosen: i => root.startPin(i)
        }
    }

    Component {
        id: rowsView
        Rows {
            pins: root.pins
            startedIndex: root.startedIndex
            reducedMotion: root.reducedMotion
            onChosen: i => root.startPin(i)
        }
    }
}
