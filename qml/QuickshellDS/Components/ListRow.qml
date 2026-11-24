pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string meta: ""
    property bool selected: false
    property bool destructive: false
    default property alias trailing: trailingSlot.data

    signal clicked()

    implicitWidth: Tokens.px(320)
    implicitHeight: root.subtitle !== "" ? Tokens.px(48) : Tokens.px(36)
    radius: Tokens.radius.sm
    opacity: root.enabled ? 1.0 : 0.45
    activeFocusOnTab: root.enabled

    color: {
        if (root.selected)
            return Tokens.color.accentMuted
        if (rowHover.hovered)
            return Tokens.veilHoverOf(Tokens.surfaceStyle)
        return "transparent"
    }

    border.width: root.selected ? Tokens.hairlineWidth : 0
    border.color: root.selected ? Tokens.color.accent : "transparent"

    Behavior on color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }

    Accessible.role: Accessible.ListItem
    Accessible.name: root.title

    FocusRing {
        active: root.activeFocus
        ringRadius: root.radius
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.lg
        anchors.rightMargin: Tokens.space.lg
        spacing: Tokens.space.md

        Icon {
            visible: root.icon !== ""
            Layout.preferredWidth: Tokens.size.iconLg
            size: Tokens.size.iconMd
            tone: {
                if (root.destructive && rowHover.hovered)
                    return "danger"
                if (root.selected)
                    return "accent"
                return "muted"
            }
            icon: root.icon
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.xxs

            TextLabel {
                Layout.fillWidth: true
                role: "body"
                font.weight: root.selected ? Font.Medium : Font.Normal
                tone: (root.destructive && rowHover.hovered) ? "danger" : "primary"
                text: root.title
            }

            TextLabel {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                role: "sm"
                tone: "muted"
                text: root.subtitle
            }
        }

        TextLabel {
            visible: root.meta !== ""
            role: "sm"
            tabular: true
            tone: "muted"
            text: root.meta
        }

        Row {
            id: trailingSlot

            spacing: Tokens.space.xs
        }
    }

    HoverHandler {
        id: rowHover

        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: {
            Tokens.keyboardNavigation = false
            root.clicked()
        }
    }

    Keys.onSpacePressed: if (root.enabled) root.clicked()
    Keys.onReturnPressed: if (root.enabled) root.clicked()
}
