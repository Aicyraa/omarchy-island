pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../Theme"

Item {
    id: root

    property string style: Tokens.surfaceStyle
    default property alias content: holder.data

    readonly property bool directionalLit: Tokens.isDirectionalLit(root.style)

    Item {
        id: holder

        anchors.fill: parent
        layer.enabled: root.directionalLit
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: lightMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Shape {
        id: lightMask

        anchors.fill: parent
        visible: false
        layer.enabled: root.directionalLit

        readonly property real cornerAngle: Math.atan2(Math.max(1, height / 2), Math.max(1, width / 2)) * 180 / Math.PI
        readonly property color fullOpacity: Qt.rgba(1, 1, 1, 1)
        readonly property color traceOpacity: Qt.rgba(1, 1, 1, Tokens.elevation.litTrace)

        ShapePath {
            strokeWidth: 0
            fillGradient: ConicalGradient {
                centerX: lightMask.width / 2
                centerY: lightMask.height / 2
                angle: 180 - lightMask.cornerAngle
                GradientStop { position: 0.0; color: lightMask.fullOpacity }
                GradientStop { position: lightMask.cornerAngle / 180; color: lightMask.traceOpacity }
                GradientStop { position: 0.5; color: lightMask.fullOpacity }
                GradientStop { position: 0.5 + lightMask.cornerAngle / 180; color: lightMask.traceOpacity }
                GradientStop { position: 1.0; color: lightMask.fullOpacity }
            }

            startX: 0
            startY: 0
            PathLine { x: lightMask.width; y: 0 }
            PathLine { x: lightMask.width; y: lightMask.height }
            PathLine { x: 0; y: lightMask.height }
            PathLine { x: 0; y: 0 }
        }
    }
}
