import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string size: "sm" // "sm" | "md"

    readonly property real padH: root.size === "md" ? Tokens.space.sm : Tokens.space.xs + Tokens.space.xxs
    readonly property real targetHeight: root.size === "md" ? Tokens.px(24) : Tokens.px(20)

    implicitWidth: Math.max(root.targetHeight, contentRow.implicitWidth + root.padH * 2)
    implicitHeight: root.targetHeight
    radius: Tokens.radius.xs
    color: Tokens.veilOf(Tokens.surfaceStyle)
    border.width: Tokens.hairlineWidth
    border.color: Tokens.veilBorderOf(Tokens.surfaceStyle)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Tokens.px(2)
        radius: parent.radius
        color: Tokens.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(0, 0, 0, 0.45)
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: Tokens.space.xxs

        Icon {
            visible: root.icon !== ""
            size: Tokens.size.iconXs
            tone: "muted"
            icon: root.icon
        }

        TextLabel {
            visible: root.text !== ""
            role: root.size === "md" ? "sm" : "caption"
            tone: "secondary"
            font.family: Tokens.type.monoFamily
            text: root.text
        }
    }
}
