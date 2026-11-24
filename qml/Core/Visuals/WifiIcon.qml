import QtQuick
import QtQuick.Shapes
import ".."
import "../../QuickshellDS/Theme"
import "Icons.js" as Icons

// The Wi-Fi fan icon, used in the idle pill AND in panels. Its three arcs light up
// with signal strength (animated), so the glyph carries meaning. `off` draws the
// crossed-out version; `level` is 0..1.
Item {
  id: root
  property real level: 0
  property bool off: false
  property real size: Tokens.size.iconMd
  property color color: Tokens.color.text
  property real strokeWidth: 1.8
  // matchBattery: shrink the glyph so its top and bottom line up with the battery glyph beside it in the
  // bar. The stroke keeps its weight (it is widened to compensate for the scale), so only the PATH height
  // matters: the battery body path is 8 grid units tall (y 8..16), the full Wi-Fi path is 14 (arc apex
  // y 5.28 to the dot at y 19.3). So the glyph is scaled by 8 / 14 = 0.571 about its own centre (y 12.29)
  // and moved up 0.9 (0.29 to share the centre line y = 12, plus 0.6 = half a pixel that the pixel
  // measurement showed it still sat low, because a thin curve antialiases lighter than the battery's edge).
  property bool matchBattery: false
  readonly property real k: matchBattery ? 8 / 14 : 1.0
  readonly property real sw: strokeWidth / k
  implicitWidth: size; implicitHeight: size

  function on(threshold) { return !off && level > threshold ? 1 : 0.28 }
  property real a1: on(0.0)
  property real a2: on(0.33)
  property real a3: on(0.66)
  Behavior on a1 { enabled: !Tokens.reducedMotion && !Tokens.gameMode; NumberAnimation { duration: Tokens.motion.normal } }
  Behavior on a2 { enabled: !Tokens.reducedMotion && !Tokens.gameMode; NumberAnimation { duration: Tokens.motion.normal } }
  Behavior on a3 { enabled: !Tokens.reducedMotion && !Tokens.gameMode; NumberAnimation { duration: Tokens.motion.normal } }

  Shape {
    width: 24; height: 24; scale: root.size / 24; transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    transform: [ Scale { origin.x: 12; origin.y: 12.29; xScale: root.k; yScale: root.k }, Translate { y: root.matchBattery ? -0.9 : 0 } ]
    ShapePath { strokeColor: root.color; strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
      PathSvg { path: Icons.paths["wifi-dot"] } }
    ShapePath { strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.a1); strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: Icons.paths["wifi-1"] } }
    ShapePath { strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.a2); strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: Icons.paths["wifi-2"] } }
    ShapePath { strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.a3); strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: Icons.paths["wifi-3"] } }
    ShapePath { strokeColor: root.off ? root.color : "transparent"; strokeWidth: root.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap
      PathSvg { path: "M3.5 3.5l17 17" } }
  }
}
