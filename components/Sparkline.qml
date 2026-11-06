import QtQuick
import QtQuick.Shapes
import ".."

// A real line chart: polyline plus a faint area fill. `samples` is an array of
// 0..1 values (oldest first). It always spans `slots` positions, right-aligned, so a
// short history draws on the right with a flat "collecting" baseline on the left.
Item {
  id: root
  property var samples: []
  property int slots: 60
  property color color: Theme.accentInk
  property real lineWidth: 2

  readonly property real dx: width / (slots - 1)
  function yOf(v) { return height - 2 - Math.max(0, Math.min(1, v)) * (height - 4) }
  readonly property var pts: {
    var out = [], n = samples.length, off = slots - n
    for (var i = 0; i < n; i++) out.push(Qt.point((off + i) * dx, yOf(samples[i])))
    return out
  }
  readonly property var area: {
    if (pts.length < 2) return []
    var a = pts.slice()
    a.push(Qt.point(pts[pts.length - 1].x, height)); a.push(Qt.point(pts[0].x, height))
    return a
  }

  // baseline for the part that has no data yet
  Rectangle { x: 0; y: parent.height - 2; width: root.samples.length > 0 ? (root.slots - root.samples.length) * root.dx : parent.width; height: 1
    color: Theme.outline; opacity: 0.5 }

  Shape {
    anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
    ShapePath { strokeWidth: 0; strokeColor: "transparent"
      fillColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.18)
      PathPolyline { path: root.area } }
    ShapePath { strokeWidth: root.lineWidth; strokeColor: root.color; fillColor: "transparent"; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
      PathPolyline { path: root.pts } }
  }
}
