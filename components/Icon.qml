import QtQuick
import QtQuick.Shapes
import ".."
import "Icons.js" as Icons

// Renders one icon from Icons.js. `Shape` + `PathSvg` draw the vector path in
// QML, so the colour comes from Theme (and animates with it) and the stroke is
// resolution-independent. The path is authored on a 24x24 grid; we draw it at
// that size and scale the whole Shape to `size`.
Item {
  id: root
  property string name: ""
  property real size: 20
  property color color: Theme.text
  property real strokeWidth: 1.8      // in 24-grid units, so it scales with size
  implicitWidth: size
  implicitHeight: size

  Behavior on color { ColorAnimation { duration: 250 } }

  Shape {
    width: 24; height: 24
    scale: root.size / 24
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer   // anti-aliased curves, no MSAA needed
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: Icons.paths[root.name] || "" }
    }
  }
}
