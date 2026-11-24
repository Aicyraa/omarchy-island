pragma ComponentBehavior: Bound

import QtQuick
import "../Theme"

Rectangle {
    id: root

    property string material: Tokens.surfaceStyle // "classic" | "glass" | "liquid"
    property string role: "ground"                // "ground" | "card" | "elevated" | "bare"
    property bool sheen: true
    property bool topHighlight: true
    property bool showBorder: true
    property bool hovered: false
    property real padding: 0
    property real horizontalPadding: root.padding
    property real verticalPadding: root.padding

    default property alias content: inner.data

    radius: Tokens.radius.md
    color: {
        if (root.role === "bare")
            return "transparent"
        if (root.role === "ground")
            return Tokens.groundOf(root.material)
        if (root.role === "elevated")
            return Tokens.isTranslucent(root.material)
                ? Tokens.veilHoverOf(root.material)
                : Tokens.color.surfaceRaised
        return root.hovered
            ? Tokens.veilHoverOf(root.material)
            : Tokens.veilOf(root.material)
    }

    border.width: (root.showBorder && root.role !== "bare") ? Tokens.hairlineWidth : 0
    border.color: root.role === "ground"
        ? Tokens.rimOf(root.material)
        : Tokens.veilBorderOf(root.material)

    Behavior on color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }
    Behavior on border.color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }

    Loader {
        anchors.fill: parent
        active: root.sheen && root.role === "ground" && Tokens.isTranslucent(root.material)
        sourceComponent: GlassSheen {
            shape: root
            style: root.material
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.max(Tokens.space.xs, root.radius)
        anchors.rightMargin: Math.max(Tokens.space.xs, root.radius)
        height: Tokens.hairlineWidth
        visible: root.topHighlight && !Tokens.isTranslucent(root.material) && !Tokens.isLight && (root.role === "card" || root.role === "elevated")
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.09) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Item {
        id: inner

        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding
    }
}
