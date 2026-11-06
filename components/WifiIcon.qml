import QtQuick
import QtQuick.Shapes
import ".."
import "Icons.js" as Icons

// The Wi-Fi fan icon, used in the idle pill AND in panels. Its three arcs light up
// with signal strength (animated), so the glyph carries meaning. `off` draws the
// crossed-out version; `level` is 0..1.
Item {
  id: root
  property real level: 0
  property bool off: false
  property real size: Theme.iconMd
  property color color: Theme.text
  implicitWidth: size; implicitHeight: size

  function on(threshold) { return !off && level > threshold ? 1 : 0.28 }
  property real a1: on(0.0)
  property real a2: on(0.33)
  property real a3: on(0.66)
  Behavior on a1 { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 220 } }
  Behavior on a2 { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 220 } }
  Behavior on a3 { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 220 } }

  Shape {
    width: 24; height: 24; scale: root.size / 24; transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    ShapePath { strokeColor: root.color; strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
      PathSvg { path: Icons.paths["wifi-dot"] } }
    ShapePath { strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.a1); strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: Icons.paths["wifi-1"] } }
    ShapePath { strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.a2); strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: Icons.paths["wifi-2"] } }
    ShapePath { strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.a3); strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: Icons.paths["wifi-3"] } }
    ShapePath { strokeColor: root.off ? root.color : "transparent"; strokeWidth: 1.8; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: "M3.5 3.5l17 17" } }
  }
}
