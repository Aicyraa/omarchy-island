import QtQuick
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property string iconName: ""
    property int count: 0
    property string tone: "accent" // "accent" | "danger" | "success" | "warning" | "info"
    property real size: Tokens.px(18)

    readonly property color badgeColor: {
        switch (root.tone) {
        case "danger":  return Tokens.color.danger
        case "success": return Tokens.color.success
        case "warning": return Tokens.color.warning
        case "info":    return Tokens.color.info
        default:        return Tokens.color.accent
        }
    }

    visible: root.iconName !== "" || root.count > 0
    width: root.count > 0 && root.iconName === ""
        ? Math.max(root.size, countLabel.implicitWidth + Tokens.space.sm)
        : root.size
    height: root.size
    radius: root.iconName !== "" ? root.size * 0.28 : Tokens.radius.pill
    color: root.iconName !== "" ? Tokens.color.islandGround : root.badgeColor
    border.width: Tokens.hairlineWidth
    border.color: Tokens.color.border

    Icon {
        anchors.centerIn: parent
        visible: root.iconName !== ""
        size: root.size * 0.72
        tone: "primary"
        name: root.iconName
    }

    TextLabel {
        id: countLabel

        anchors.centerIn: parent
        visible: root.iconName === "" && root.count > 0
        role: "caption"
        tabular: true
        tone: "onAccent"
        font.weight: Font.Medium
        text: root.count > 99 ? "99+" : String(root.count)
    }
}
