pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../Theme"

Item {
    id: root

    property bool running: true
    property real size: Tokens.size.iconLg
    property real thickness: Tokens.px(2.5)
    property color color: Tokens.color.accent

    implicitWidth: root.size
    implicitHeight: root.size

    Accessible.role: Accessible.Indicator
    Accessible.name: qsTr("Loading")

    Shape {
        id: arc

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: Tokens.motion.slow * 3
            loops: Animation.Infinite
            running: root.running && root.visible && !Tokens.reducedMotion && !Tokens.gameMode
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: Math.max(1, root.width / 2 - root.thickness / 2)
                radiusY: Math.max(1, root.height / 2 - root.thickness / 2)
                startAngle: 0
                sweepAngle: 250
            }
        }
    }
}
