import QtQuick
import QtQuick.Shapes

// Analytically anti-aliased rounded rectangle/circle using Qt 6 Shape.CurveRenderer.
// Renders silky-smooth curves on 1x DPI displays without offscreen FBO rasterization
// and without blurring sibling or child Label text.
Shape {
  id: root
  readonly property bool isBgSurface: true
  property color color: "transparent"
  property color borderColor: "transparent"
  property real borderWidth: 0
  property real radius: 0
  property real topLeftRadius: -1
  property real topRightRadius: -1
  property real bottomLeftRadius: -1
  property real bottomRightRadius: -1

  readonly property bool valid: width > 0.5 && height > 0.5
  readonly property real maxR: Math.max(0, Math.min(width, height) / 2)
  readonly property real tlR: Math.min(maxR, Math.max(0, topLeftRadius >= 0 ? topLeftRadius : radius))
  readonly property real trR: Math.min(maxR, Math.max(0, topRightRadius >= 0 ? topRightRadius : radius))
  readonly property real blR: Math.min(maxR, Math.max(0, bottomLeftRadius >= 0 ? bottomLeftRadius : radius))
  readonly property real brR: Math.min(maxR, Math.max(0, bottomRightRadius >= 0 ? bottomRightRadius : radius))

  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    fillColor: root.valid ? root.color : "transparent"
    strokeWidth: (root.valid && root.borderWidth > 0) ? root.borderWidth : -1
    strokeColor: (root.valid && root.borderWidth > 0) ? root.borderColor : "transparent"
    joinStyle: ShapePath.RoundJoin

    PathRectangle {
      width: root.valid ? root.width : 0
      height: root.valid ? root.height : 0
      strokeAdjustment: root.borderWidth > 0 ? root.borderWidth : 0
      topLeftRadius: root.tlR
      topRightRadius: root.trR
      bottomLeftRadius: root.blR
      bottomRightRadius: root.brR
    }
  }
}
