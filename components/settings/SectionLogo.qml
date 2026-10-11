import QtQuick
import QtQuick.Shapes
import "SectionLogos.js" as Logos

// A rail logo drawn as a stroked shape so it takes any theme colour. Static:
// nothing is redrawn unless the colour changes.
Item {
    id: logo

    required property string sectionId
    property color color: "white"
    property real size: 20

    width: size
    height: size

    Shape {
        width: 24
        height: 24
        scale: logo.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.8
            strokeColor: logo.color
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: Logos.pathFor(logo.sectionId)
            }
        }
    }
}
