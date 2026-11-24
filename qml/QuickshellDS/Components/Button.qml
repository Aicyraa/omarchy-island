pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "secondary" // "primary" | "secondary" | "ghost" | "danger"
    property string shape: "pill"        // "pill" | "rounded" | "circle"
    property string size: "md"           // "sm" | "md" | "lg"
    property bool active: false
    property bool loading: false
    property string accessibleLabel: ""

    signal clicked()

    readonly property bool isPrimary: root.variant === "primary" || root.active
    readonly property bool isDanger: root.variant === "danger"
    readonly property bool isGhost: root.variant === "ghost" && !root.active
    readonly property bool iconOnly: root.text === "" && root.icon !== ""

    readonly property real targetHeight: {
        switch (root.size) {
        case "sm": return Tokens.size.controlSm
        case "lg": return Tokens.size.controlLg
        default:   return Tokens.size.controlMd
        }
    }

    implicitHeight: root.targetHeight
    implicitWidth: root.shape === "circle" || root.iconOnly
        ? Math.max(root.targetHeight, layout.implicitWidth + Tokens.space.md)
        : layout.implicitWidth + Tokens.space.lg * 2

    radius: {
        switch (root.shape) {
        case "circle":
        case "pill": return Tokens.radius.pill
        default:     return Tokens.radius.sm
        }
    }

    opacity: root.enabled ? 1.0 : 0.45
    scale: (tap.pressed && root.enabled && !Tokens.reducedMotion && !Tokens.gameMode) ? 0.97 : 1.0
    activeFocusOnTab: root.enabled

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleLabel !== "" ? root.accessibleLabel : root.text

    color: {
        if (root.isDanger)
            return hover.hovered ? Qt.lighter(Tokens.color.danger, 1.1) : Tokens.color.danger
        if (root.isPrimary)
            return hover.hovered ? Tokens.color.accentHover : Tokens.color.accent
        if (root.isGhost)
            return hover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : "transparent"
        return hover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : Tokens.veilOf(Tokens.surfaceStyle)
    }

    border.width: root.isGhost && !hover.hovered ? 0 : Tokens.hairlineWidth
    border.color: {
        if (root.isDanger)
            return Tokens.color.danger
        if (root.isPrimary)
            return Tokens.color.accent
        return hover.hovered ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)
    }

    Behavior on color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }
    Behavior on border.color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }
    Behavior on scale {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
    }

    FocusRing {
        active: root.activeFocus
        ringRadius: root.radius === Tokens.radius.pill ? Tokens.radius.pill : root.radius
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.space.xs

        TextLabel {
            visible: root.loading
            role: "mono"
            tone: (root.isPrimary || root.isDanger) ? "onAccent" : "accent"
            text: "󰔟"
        }

        Icon {
            visible: !root.loading && root.icon !== ""
            size: root.size === "sm" ? Tokens.size.iconSm : Tokens.size.iconMd
            tone: {
                if (root.isPrimary || root.isDanger)
                    return "onAccent"
                return hover.hovered ? "accent" : "primary"
            }
            icon: root.icon
        }

        TextLabel {
            visible: root.text !== ""
            role: root.size === "sm" ? "sm" : "body"
            tone: (root.isPrimary || root.isDanger) ? "onAccent" : "primary"
            font.weight: root.isPrimary ? Font.Medium : Font.Normal
            text: root.text
        }
    }

    HoverHandler {
        id: hover

        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: tap

        enabled: root.enabled && !root.loading
        onTapped: {
            Tokens.keyboardNavigation = false
            root.clicked()
        }
    }

    Keys.onSpacePressed: {
        if (root.enabled && !root.loading)
            root.clicked()
    }
    Keys.onReturnPressed: {
        if (root.enabled && !root.loading)
            root.clicked()
    }
}
