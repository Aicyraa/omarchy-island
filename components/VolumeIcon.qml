import QtQuick
import QtQuick.Shapes
import ".."
import "Icons.js" as Icons

// Speaker whose sound waves GROW with the volume: wave 1 fades in above ~10%,
// wave 2 above ~55%. The fade is a Behavior on a plain number (w1/w2), and the
// wave's stroke colour is the icon colour with that number as its alpha. Muted
// swaps the body for a speaker with a cross and hides both waves.
Item {
  id: root
  property real level: 0          // 0..1
  property bool muted: false
  property real size: 20
  property color color: Theme.text
  implicitWidth: size; implicitHeight: size

  property real w1: (!muted && level > 0.1) ? 1 : 0
  property real w2: (!muted && level > 0.55) ? 1 : 0
  Behavior on w1 { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 180 } }
  Behavior on w2 { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 180 } }

  Shape {
    width: 24; height: 24; scale: root.size / 24; transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.color; strokeWidth: 1.8; fillColor: "transparent"
      capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.muted ? Icons.paths["volume-off"] : Icons.paths["volume"] }
    }
    ShapePath {
      strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.w1)
      strokeWidth: 1.8; fillColor: "transparent"
      capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
      PathSvg { path: Icons.paths["volume-w1"] }
    }
    ShapePath {
      strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.w2)
      strokeWidth: 1.8; fillColor: "transparent"
      capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
      PathSvg { path: Icons.paths["volume-w2"] }
    }
  }
}
