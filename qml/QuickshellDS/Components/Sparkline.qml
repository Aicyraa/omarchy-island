pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../Theme"

Item {
    id: root

    property var values: []
    property real minValue: 0
    property real maxValue: 100
    property bool fillArea: true
    property bool showEndpoint: true
    property real strokeWidth: Tokens.px(2)
    property color lineColor: Tokens.color.accent

    readonly property real range: Math.max(0.0001, root.maxValue - root.minValue)
    readonly property int count: root.values ? root.values.length : 0

    implicitWidth: Tokens.px(160)
    implicitHeight: Tokens.px(44)

    function xAt(idx: int): real {
        if (root.count <= 1)
            return root.width
        return (idx / (root.count - 1)) * root.width
    }

    function yAt(val: real): real {
        const pad = root.strokeWidth + Tokens.px(2)
        const usableH = Math.max(1, root.height - pad * 2)
        const norm = Math.max(0, Math.min(1, (val - root.minValue) / root.range))
        return pad + usableH * (1 - norm)
    }

    readonly property string svgPathData: {
        if (root.count < 2 || root.width <= 0 || root.height <= 0)
            return ""
        let d = `M ${root.xAt(0).toFixed(2)} ${root.yAt(Number(root.values[0])).toFixed(2)}`
        for (let i = 1; i < root.count; ++i)
            d += ` L ${root.xAt(i).toFixed(2)} ${root.yAt(Number(root.values[i])).toFixed(2)}`
        return d
    }

    readonly property string areaPathData: {
        if (!root.fillArea || root.svgPathData === "")
            return ""
        return `${root.svgPathData} L ${root.width.toFixed(2)} ${root.height.toFixed(2)} L 0 ${root.height.toFixed(2)} Z`
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.count >= 2

        ShapePath {
            strokeWidth: 0
            fillColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.height
                GradientStop { position: 0.0; color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.28) }
                GradientStop { position: 1.0; color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.0) }
            }

            PathSvg { path: root.areaPathData }
        }

        ShapePath {
            strokeWidth: root.strokeWidth
            strokeColor: root.lineColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg { path: root.svgPathData }
        }
    }

    Rectangle {
        visible: root.showEndpoint && root.count >= 2
        width: Tokens.px(6)
        height: width
        radius: Tokens.radius.pill
        x: root.width - width / 2
        y: root.count >= 2 ? root.yAt(Number(root.values[root.count - 1])) - height / 2 : 0
        color: root.lineColor
        border.width: Tokens.hairlineWidth
        border.color: Tokens.color.onAccent
    }
}
