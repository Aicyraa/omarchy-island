pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool active: false
    property bool available: true
    property bool expandable: false

    signal toggled()
    signal expanded()

    implicitWidth: Tokens.px(140)
    implicitHeight: Tokens.px(64)
    radius: Tokens.radius.md
    opacity: root.available ? 1.0 : 0.45
    activeFocusOnTab: root.available

    color: tileHover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : Tokens.veilOf(Tokens.surfaceStyle)
    border.width: Tokens.hairlineWidth
    border.color: root.active ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

    Behavior on color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }
    Behavior on border.color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.label

    FocusRing {
        active: root.activeFocus
        ringRadius: root.radius
    }

    RowLayout {
        z: 1
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.lg
        anchors.rightMargin: Tokens.space.lg
        anchors.topMargin: Tokens.space.md
        anchors.bottomMargin: Tokens.space.md
        spacing: Tokens.space.md

        Rectangle {
            Layout.preferredWidth: Tokens.px(34)
            Layout.preferredHeight: Tokens.px(34)
            Layout.alignment: Qt.AlignVCenter
            radius: Tokens.radius.pill
            color: root.active ? Tokens.color.accent : Tokens.veilHoverOf(Tokens.surfaceStyle)

            Behavior on color {
                enabled: !Tokens.reducedMotion && !Tokens.gameMode
                ColorAnimation { duration: Tokens.motion.fast }
            }

            Icon {
                anchors.centerIn: parent
                size: Tokens.size.iconMd
                tone: root.active ? "onAccent" : "muted"
                icon: root.icon
            }

            HoverHandler {
                enabled: root.available && root.expandable
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.available && root.expandable
                onTapped: root.toggled()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: root.expandable ? Tokens.space.lg : 0
            spacing: Tokens.space.xxs

            TextLabel {
                Layout.fillWidth: true
                role: "sm"
                font.weight: Font.Medium
                tone: "primary"
                text: root.label
            }

            TextLabel {
                Layout.fillWidth: true
                visible: root.detail !== ""
                role: "caption"
                tone: root.active ? "accent" : "muted"
                text: root.detail
            }
        }
    }

    HoverHandler {
        id: tileHover

        enabled: root.available
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.available
        onTapped: {
            Tokens.keyboardNavigation = false
            if (root.expandable)
                root.expanded()
            else
                root.toggled()
        }
    }

    Item {
        z: 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Tokens.size.hitMin
        visible: root.expandable

        Icon {
            anchors.centerIn: parent
            size: Tokens.size.iconSm
            tone: chevronHover.hovered ? "accent" : "muted"
            name: "chevron-right"
        }

        HoverHandler {
            id: chevronHover

            enabled: root.available
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: root.available
            onTapped: root.expanded()
        }
    }

    Keys.onSpacePressed: if (root.available) root.toggled()
    Keys.onReturnPressed: if (root.available) (root.expandable ? root.expanded() : root.toggled())
}
