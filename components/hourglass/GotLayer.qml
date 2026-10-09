import QtQuick

// Base of the two Glass of Time layers (the sphere and the gold ring): a
// canvas sized on the sphere and centered on the hourglass body. Repainted
// only on resize, when it appears, or on a freeze step.
Canvas {
    id: root

    required property var dim
    required property GotPalette gotColors
    required property real frost
    required property color frostColor
    // Freeze in 24 steps (see Hourglass.frostStep): the paint is not redone
    // for every frame of the freeze.
    required property int frostStep

    width: dim.sphereR * 2 + 8
    height: width
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    renderTarget: Canvas.FramebufferObject
    onWidthChanged: requestPaint()
    onVisibleChanged: if (visible)
        requestPaint()
    onFrostStepChanged: requestPaint()

    // Ring geometry, shared by both layers (sphere-centered)
    readonly property real ringRx: dim.sphereR
    readonly property real ringRy: dim.sphereR * 0.2
    readonly property real ringTop: -dim.sphereR * 0.14
    readonly property real ringBottom: dim.sphereR * 0.14
}
