import QtQuick
import qs.Common

// The 2 px keyboard focus ring, 4 px inside its parent (the mockup's outline-offset).
Rectangle {
    anchors.fill: parent
    anchors.margins: 4
    radius: Theme.cornerRadius
    color: "transparent"
    border.width: 2
}
