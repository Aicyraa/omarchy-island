pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../Theme"
import "../Primitives"

Item {
    id: root

    property var values: [] // [number, ...]
    property real fill: 1.0
    property real size: Tokens.px(68)
    property real thickness: Tokens.px(6)
    property color accent: Tokens.color.accent
    property string centerText: ""
    property string centerSubtext: ""

    readonly property real total: {
        if (!root.values || root.values.length === 0)
            return 0
        let sum = 0
        for (let i = 0; i < root.values.length; ++i)
            sum += Math.max(0, Number(root.values[i]))
        return sum
    }
    readonly property real arcRadius: Math.max(1, Math.min(root.width, root.height) / 2 - root.thickness / 2)
    readonly property real seamDeg: root.values && root.values.filter(v => Number(v) > 0).length > 1 ? 4 : 0
    readonly property var alphaSteps: [1.0, 0.65, 0.42, 0.26]

    implicitWidth: root.size
    implicitHeight: root.size

    function segmentColor(idx: int): color {
        const a = idx < root.alphaSteps.length ? root.alphaSteps[idx] : 0.16
        return Qt.rgba(root.accent.r, root.accent.g, root.accent.b, a)
    }

    function beforeSum(idx: int): real {
        let sum = 0
        for (let i = 0; i < idx && i < root.values.length; ++i)
            sum += Math.max(0, Number(root.values[i]))
        return sum
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Tokens.veilHoverOf(Tokens.surfaceStyle)
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
    }

    Repeater {
        model: root.values ? root.values.length : 0

        Shape {
            id: segArc

            required property int index
            readonly property real val: Math.max(0, Number(root.values[segArc.index]))
            readonly property real share: root.total > 0 ? (360 * Math.max(0, Math.min(1, root.fill)) / root.total) : 0

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: segArc.val > 0 && root.total > 0

            ShapePath {
                strokeColor: root.segmentColor(segArc.index)
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.width / 2
                    centerY: root.height / 2
                    radiusX: root.arcRadius
                    radiusY: root.arcRadius
                    startAngle: -90 + root.beforeSum(segArc.index) * segArc.share
                    sweepAngle: Math.max(0.5, segArc.val * segArc.share - root.seamDeg)
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: root.centerText !== "" || root.centerSubtext !== ""
        spacing: 0

        TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.centerText !== ""
            role: "subtitle"
            tabular: true
            font.weight: Font.Medium
            text: root.centerText
        }

        TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.centerSubtext !== ""
            role: "caption"
            tone: "muted"
            text: root.centerSubtext
        }
    }
}
