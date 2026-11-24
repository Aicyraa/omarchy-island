import QtQuick
import QtQuick.Shapes
import "../Theme"
import "../Primitives"

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property string unit: ""
    property string label: ""
    property real size: Tokens.px(88)
    property real thickness: Tokens.px(6)
    property bool autoThreshold: true
    property color fillColor: Tokens.color.accent

    readonly property real ratio: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from)))
    readonly property real arcRadius: Math.max(1, Math.min(root.width, root.height) / 2 - root.thickness / 2)
    readonly property color effectiveColor: {
        if (!root.autoThreshold)
            return root.fillColor
        if (root.ratio >= 0.90)
            return Tokens.color.danger
        if (root.ratio >= 0.75)
            return Tokens.color.warning
        return root.fillColor
    }

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Tokens.veilHoverOf(Tokens.surfaceStyle)
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: 135
                sweepAngle: 270
            }
        }

        ShapePath {
            strokeColor: root.effectiveColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: 135
                sweepAngle: 270 * root.ratio
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "title"
            tabular: true
            text: `${Math.round(root.value)}${root.unit}`
        }

        TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.label !== ""
            role: "caption"
            tone: "muted"
            text: root.label
        }
    }
}
