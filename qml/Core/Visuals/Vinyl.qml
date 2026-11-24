import QtQuick
import QtQuick.Shapes
import ".."
import "../../QuickshellDS/Theme"

// A vinyl record, drawn from gradients: the stand-in for cover art when a track has none (or while it loads).
// Black disc with fine grooves, a theme-coloured label with a small mark so the spin is visible, a centre hole and
// a fixed two-wedge sheen (the light does not rotate with the record). It spins while `spinning`, and keeps its angle
// when paused.
Item {
  id: root
  property bool spinning: false
  property color label: Tokens.color.accent
  implicitWidth: 84; implicitHeight: 84
  readonly property real s: Math.min(width, height)
  readonly property real c: s / 2

  // everything that turns with the record
  Item {
    id: turntable
    anchors.fill: parent
    NumberAnimation on rotation { running: root.spinning && !IslandState.reducedMotion; from: rotation; to: rotation + 360
      duration: 4200; loops: Animation.Infinite }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      // body
      ShapePath {
        strokeWidth: 0
        fillGradient: RadialGradient { centerX: root.c; centerY: root.c; centerRadius: root.c; focalX: root.c; focalY: root.c
          GradientStop { position: 0.0; color: Qt.rgba(0.17, 0.17, 0.19, 1) }
          GradientStop { position: 0.55; color: Qt.rgba(0.07, 0.07, 0.08, 1) }
          GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.03, 0.04, 1) } }
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.c - 0.5; radiusY: root.c - 0.5; startAngle: 0; sweepAngle: 360 }
      }
      // grooves
      ShapePath { strokeColor: Qt.rgba(1, 1, 1, 0.07); strokeWidth: 0.7; fillColor: "transparent"
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.s * 0.46; radiusY: root.s * 0.46; startAngle: 0; sweepAngle: 360 } }
      ShapePath { strokeColor: Qt.rgba(1, 1, 1, 0.05); strokeWidth: 0.7; fillColor: "transparent"
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.s * 0.42; radiusY: root.s * 0.42; startAngle: 0; sweepAngle: 360 } }
      ShapePath { strokeColor: Qt.rgba(1, 1, 1, 0.07); strokeWidth: 0.7; fillColor: "transparent"
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.s * 0.38; radiusY: root.s * 0.38; startAngle: 0; sweepAngle: 360 } }
      ShapePath { strokeColor: Qt.rgba(1, 1, 1, 0.05); strokeWidth: 0.7; fillColor: "transparent"
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.s * 0.34; radiusY: root.s * 0.34; startAngle: 0; sweepAngle: 360 } }
      // label
      ShapePath {
        strokeWidth: 0
        fillGradient: RadialGradient { centerX: root.c; centerY: root.c; centerRadius: root.s * 0.27; focalX: root.c - root.s * 0.05; focalY: root.c - root.s * 0.06
          GradientStop { position: 0.0; color: Qt.lighter(root.label, 1.25) }
          GradientStop { position: 1.0; color: Qt.darker(root.label, 1.35) } }
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.s * 0.27; radiusY: root.s * 0.27; startAngle: 0; sweepAngle: 360 }
      }
      // a mark on the label, so the rotation can be seen
      ShapePath { strokeColor: Qt.rgba(1, 1, 1, 0.55); strokeWidth: 1.2; capStyle: ShapePath.RoundCap; fillColor: "transparent"
        PathMove { x: root.c; y: root.c - root.s * 0.22 }
        PathLine { x: root.c; y: root.c - root.s * 0.14 } }
      // centre hole
      ShapePath { strokeWidth: 0; fillColor: Qt.rgba(0.05, 0.05, 0.06, 1)
        PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.s * 0.035; radiusY: root.s * 0.035; startAngle: 0; sweepAngle: 360 } }
    }
  }

  // the sheen and the rim stay put
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: 0
      fillGradient: ConicalGradient { centerX: root.c; centerY: root.c; angle: 35
        GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 0.07; color: Qt.rgba(1, 1, 1, 0.30) }
        GradientStop { position: 0.14; color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 0.57; color: Qt.rgba(1, 1, 1, 0.22) }
        GradientStop { position: 0.64; color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) } }
      PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.c - 0.5; radiusY: root.c - 0.5; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath { strokeColor: Qt.rgba(1, 1, 1, 0.12); strokeWidth: 0.8; fillColor: "transparent"
      PathAngleArc { centerX: root.c; centerY: root.c; radiusX: root.c - 0.5; radiusY: root.c - 0.5; startAngle: 0; sweepAngle: 360 } }
  }
}
