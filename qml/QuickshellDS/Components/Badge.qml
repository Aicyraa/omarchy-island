import QtQuick
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property string text: ""
    // "neutral" | "accent" | "success" | "warning" | "danger" | "info"
    property string tone: "neutral"

    readonly property color tintColor: {
        switch (root.tone) {
        case "accent":  return Tokens.color.accent
        case "success": return Tokens.color.success
        case "warning": return Tokens.color.warning
        case "danger":  return Tokens.color.danger
        case "info":    return Tokens.color.info
        default:        return Tokens.color.textMuted
        }
    }

    implicitWidth: badgeText.implicitWidth + Tokens.space.sm * 2
    implicitHeight: badgeText.implicitHeight + Tokens.space.xxs * 2
    radius: Tokens.radius.pill
    color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b, 0.16)
    border.width: Tokens.hairlineWidth
    border.color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b, 0.35)

    TextLabel {
        id: badgeText

        anchors.centerIn: parent
        role: "caption"
        tabular: true
        font.weight: Font.Medium
        color: root.tone === "neutral" ? Tokens.color.textSecondary : root.tintColor
        text: root.text
    }
}
