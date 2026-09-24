import QtQuick
import QtQuick.Shapes

// Anneau qui se vide dans le sens horaire depuis midi, bouts arrondis.
Item {
    id: root

    property real progress: 1
    property real thickness: 2
    property color color: "white"
    property color trackColor: "transparent"
    property bool animated: true

    implicitWidth: 16
    implicitHeight: 16

    property real _shown: progress
    // On n'anime que les vrais sauts (+1 min, minuteurs courts) : un pas
    // invisible (< 0,4 %) est appliqué tel quel, sans repeindre 20 images.
    Behavior on _shown {
        enabled: root.animated && Math.abs(root.progress - root._shown) > 0.004
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    readonly property real _r: Math.max(0, Math.min(width, height) / 2 - thickness / 2)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._r
                radiusY: root._r
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root._shown > 0.001 ? root.color : "transparent"
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._r
                radiusY: root._r
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root._shown))
            }
        }
    }
}
