import QtQuick

// Holds one Glass of Time layer, created only while that style is on: each
// layer is a framebuffer canvas the classic style never needs. The slot is
// centered by hand: anchors.centerIn rounds to whole pixels and would shift
// the layer by half a pixel against the glass.
Loader {
    required property var dim

    width: dim.gotSize
    height: width
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
}
