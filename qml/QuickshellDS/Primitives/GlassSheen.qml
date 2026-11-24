pragma ComponentBehavior: Bound

import QtQuick
import "../Theme"

Item {
    id: root

    required property Rectangle shape
    property string style: Tokens.surfaceStyle
    property bool edges: true

    anchors.fill: parent
    visible: Tokens.isTranslucent(root.style)

    component BevelBand: Rectangle {
        required property int inset
        required property real strength

        anchors.fill: parent
        anchors.margins: inset
        color: "transparent"
        border.width: Tokens.hairlineWidth
        border.color: Qt.rgba(1, 1, 1, Tokens.edgeStrengthOf(root.style) * strength)
        radius: Tokens.innerRadius(root.shape.radius, inset)
        topLeftRadius: Tokens.innerRadius(root.shape.topLeftRadius, inset)
        topRightRadius: Tokens.innerRadius(root.shape.topRightRadius, inset)
        bottomLeftRadius: Tokens.innerRadius(root.shape.bottomLeftRadius, inset)
        bottomRightRadius: Tokens.innerRadius(root.shape.bottomRightRadius, inset)
    }

    Rectangle {
        id: topSheen

        anchors.fill: parent
        radius: root.shape.radius
        topLeftRadius: root.shape.topLeftRadius
        topRightRadius: root.shape.topRightRadius
        bottomLeftRadius: root.shape.bottomLeftRadius
        bottomRightRadius: root.shape.bottomRightRadius

        readonly property real span: Tokens.elevation.glassSheenDepth / Math.max(1, height)

        gradient: Gradient {
            GradientStop { position: 0.0; color: Tokens.sheenOf(root.style) }
            GradientStop {
                position: Math.min(1.0, topSheen.span)
                color: Qt.rgba(1, 1, 1, Tokens.sheenOf(root.style).a * Math.max(0, 1 - 1 / topSheen.span))
            }
        }
    }

    LitEdge {
        anchors.fill: parent
        style: root.style
        visible: root.edges

        Rectangle {
            anchors.fill: parent
            visible: Tokens.isDirectionalLit(root.style)
            color: "transparent"
            border.width: Tokens.hairlineWidth
            border.color: Qt.rgba(1, 1, 1, Tokens.elevation.litRim)
            radius: root.shape.radius
            topLeftRadius: root.shape.topLeftRadius
            topRightRadius: root.shape.topRightRadius
            bottomLeftRadius: root.shape.bottomLeftRadius
            bottomRightRadius: root.shape.bottomRightRadius
        }

        BevelBand { inset: 1; strength: 1.0 }
        BevelBand { inset: 2; strength: 0.6 }
        BevelBand { inset: 3; strength: 0.35 }
        BevelBand { inset: 4; strength: 0.15 }
    }
}
