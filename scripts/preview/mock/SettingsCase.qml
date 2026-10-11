import QtQuick
import qs.Common
import "../../.."

// One settings page at a given width, filled from a made-up store.
Item {
    property alias pageWidth: page.width
    property alias preset: page.store
    readonly property alias page: page
    // Preview only: types a query into the page search box (empty = browse)
    property string query: ""
    onQueryChanged: {
        const find = item => {
            if (item.section !== undefined && item.query !== undefined)
                return item;
            for (const c of item.children) {
                const hit = find(c);
                if (hit)
                    return hit;
            }
            return null;
        };
        const host = find(page);
        if (host)
            host.query = query;
    }
    width: page.width
    height: page.height

    // The page paints no background of its own: the settings panel does
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    TimerSettings {
        id: page
    }
}
