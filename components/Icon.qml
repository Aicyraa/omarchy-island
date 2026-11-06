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
  // matchBattery: scale the glyph so its path is as tall as the battery body (8 grid units) and centre it on the
  // battery's centre line (y = 12), so status icons in the bar line up with the battery and the Wi-Fi glyph.
  // The stroke keeps its weight (widened to compensate for the scale).
  property bool matchBattery: false
  readonly property var ext: Icons.extent[name] || [3, 21]
  readonly property real k: matchBattery ? 8 / (ext[1] - ext[0]) : 1.0
  readonly property real cy: (ext[0] + ext[1]) / 2
  implicitWidth: size
  implicitHeight: size

  Behavior on color { ColorAnimation { duration: 250 } }

  Shape {
    width: 24; height: 24
    scale: root.size / 24
    transformOrigin: Item.TopLeft
    transform: [ Scale { origin.x: 12; origin.y: root.cy; xScale: root.k; yScale: root.k }, Translate { y: root.matchBattery ? 12 - root.cy - 1.0 : 0 } ]
    preferredRendererType: Shape.CurveRenderer   // anti-aliased curves, no MSAA needed
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth / Math.sqrt(root.k)     // eased compensation: full compensation turns small glyphs into blobs
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: Icons.paths[root.name] || "" }
    }
  }
}
