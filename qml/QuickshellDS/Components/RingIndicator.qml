import QtQuick
import QtQuick.Shapes
import "../Theme"

Item {
    id: root

    property real progress: 0
    property real size: Tokens.size.barHeight
    property real thickness: Tokens.px(3)
    property color fillColor: Tokens.color.accent
    property color trackColor: Tokens.veilHoverOf(Tokens.surfaceStyle)

    readonly property real clamped: Math.max(0, Math.min(1, root.progress))
    readonly property real arcRadius: Math.max(1, Math.min(root.width, root.height) / 2 - root.thickness / 2)

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.fillColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: -90
                sweepAngle: 360 * root.clamped
            }
        }
    }
}
