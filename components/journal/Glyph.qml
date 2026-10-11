import QtQuick
import QtQuick.Shapes

// A line icon of the journal's drawn set: paths on a 16 grid, 1.5 stroke,
// round caps and joins, in any theme colour.
Item {
    id: root

    required property string path
    required property color color
    property real size: 16

    width: size
    height: size

    Shape {
        width: 16
        height: 16
        scale: root.size / 16
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.5
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: root.path
            }
        }
    }
}
