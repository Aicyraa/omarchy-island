import QtQuick
import QtQuick.Shapes
import "../Theme"

Item {
    id: root

    property color color: Tokens.groundOf(Tokens.surfaceStyle)
    property bool mirrored: false
    property real sheenReach: 0

    implicitWidth: Tokens.radius.notch * 2
    implicitHeight: Tokens.radius.notch * 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        transform: Scale {
            xScale: root.mirrored ? -1 : 1
            origin.x: root.width / 2
        }

        ShapePath {
            strokeWidth: 0
            fillColor: root.color
            startX: 0
            startY: 0

            PathLine { x: root.width; y: 0 }
            PathAngleArc {
                centerX: root.width
                centerY: root.height
                radiusX: root.width
                radiusY: root.height
                startAngle: -90
                sweepAngle: -90
            }
            PathLine { x: 0; y: 0 }
        }

        ShapePath {
            strokeWidth: 0
            fillColor: "transparent"
            fillGradient: root.sheenReach > 0 ? sheenGradient : null
            startX: 0
            startY: 0

            PathLine { x: root.width; y: 0 }
            PathAngleArc {
                centerX: root.width
                centerY: root.height
                radiusX: root.width
                radiusY: root.height
                startAngle: -90
                sweepAngle: -90
            }
            PathLine { x: 0; y: 0 }
        }
    }

    LinearGradient {
        id: sheenGradient

        x1: 0
        y1: 0
        x2: 0
        y2: root.sheenReach
        GradientStop { position: 0.0; color: Tokens.sheenOf(Tokens.surfaceStyle) }
        GradientStop { position: 1.0; color: "transparent" }
    }
}
