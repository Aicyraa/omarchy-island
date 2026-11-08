import QtQuick
import QtQuick.Shapes
import ".."

// Soft elevation: a shadow painted only OUTSIDE a rounded shape. It is `bands` stacked rings: ring k is the shape grown
// by spread*(k+1)/bands, with the shape itself cut out (even-odd fill). Where the rings overlap near the edge the shadow
// is darkest and it fades out at `spread`. Nothing is painted under the shape, so a translucent pill never gets darker
// in its middle, and there are no rasterised shadows or layers. The shadow sits `dy` lower than the shape.
//
// Place it under the shape (lower z). The element's own x/y/size are derived from the shape's, so bind rx/ry/rw/rh to
// the shape and it follows the shape's springs.
Item {
  id: root
  property real rx: 0; property real ry: 0; property real rw: 0; property real rh: 0   // the shape (screen coordinates)
  property real tl: 0; property real tr: 0; property real br: 0; property real bl: 0   // its corner radii
  property real spread: 22          // how far the shadow reaches, px (kept inside the window)
  property real dy: 6               // the shadow falls this far below the shape
  property real strength: 0.32      // darkest alpha, reached right at the edge
  property int bands: 8

  x: rx - spread; y: ry - spread
  width: rw + 2 * spread; height: rh + 2 * spread
  visible: rw > 0 && rh > 0

  Repeater {
    model: root.bands
    delegate: Shape {
      id: ring
      required property int index
      // Ring index 0 is the innermost (smallest growth); the outermost is the faintest.
      readonly property real e: root.spread * (index + 1) / root.bands
      readonly property real ox0: root.spread - e
      readonly property real oy0: root.spread - e + root.dy
      readonly property real ox1: root.spread + root.rw + e
      readonly property real oy1: root.spread + root.rh + e + root.dy
      readonly property real otl: Math.max(0, root.tl + e)
      readonly property real otr: Math.max(0, root.tr + e)
      readonly property real obr: Math.max(0, root.br + e)
      readonly property real obl: Math.max(0, root.bl + e)
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: Qt.rgba(0, 0, 0, root.strength / root.bands)
        strokeWidth: 0; strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        // Outer outline (clockwise).
        PathMove { x: ring.ox0 + ring.otl; y: ring.oy0 }
        PathLine { x: ring.ox1 - ring.otr; y: ring.oy0 }
        PathArc { x: ring.ox1; y: ring.oy0 + ring.otr; radiusX: ring.otr; radiusY: ring.otr }
        PathLine { x: ring.ox1; y: ring.oy1 - ring.obr }
        PathArc { x: ring.ox1 - ring.obr; y: ring.oy1; radiusX: ring.obr; radiusY: ring.obr }
        PathLine { x: ring.ox0 + ring.obl; y: ring.oy1 }
        PathArc { x: ring.ox0; y: ring.oy1 - ring.obl; radiusX: ring.obl; radiusY: ring.obl }
        PathLine { x: ring.ox0; y: ring.oy0 + ring.otl }
        PathArc { x: ring.ox0 + ring.otl; y: ring.oy0; radiusX: ring.otl; radiusY: ring.otl }
        // The shape itself (the hole, counter-clockwise by the even-odd rule).
        PathMove { x: root.spread + root.tl; y: root.spread }
        PathLine { x: root.spread + root.rw - root.tr; y: root.spread }
        PathArc { x: root.spread + root.rw; y: root.spread + root.tr; radiusX: root.tr; radiusY: root.tr }
        PathLine { x: root.spread + root.rw; y: root.spread + root.rh - root.br }
        PathArc { x: root.spread + root.rw - root.br; y: root.spread + root.rh; radiusX: root.br; radiusY: root.br }
        PathLine { x: root.spread + root.bl; y: root.spread + root.rh }
        PathArc { x: root.spread; y: root.spread + root.rh - root.bl; radiusX: root.bl; radiusY: root.bl }
        PathLine { x: root.spread; y: root.spread + root.tl }
        PathArc { x: root.spread + root.tl; y: root.spread; radiusX: root.tl; radiusY: root.tl }
      }
    }
  }
}
