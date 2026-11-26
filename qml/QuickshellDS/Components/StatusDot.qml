import QtQuick
import "../Theme"

Item {
    id: root

    // "success" | "warning" | "danger" | "info" | "accent" | "muted"
    property string tone: "success"
    property real size: Tokens.px(8)
    property bool pulse: false

    readonly property color dotColor: {
        switch (root.tone) {
        case "warning": return Tokens.color.warning
        case "danger":  return Tokens.color.danger
        case "info":    return Tokens.color.info
        case "accent":  return Tokens.color.accent
        case "muted":   return Tokens.color.textMuted
        default:        return Tokens.color.success
        }
    }

    implicitWidth: root.size * 2
    implicitHeight: root.size * 2

    Rectangle {
        id: halo

        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: Tokens.radius.pill
        color: root.dotColor
        visible: root.pulse && root.visible && !Tokens.reducedMotion && !Tokens.gameMode
        opacity: 0.45

        SequentialAnimation on scale {
            running: halo.visible
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.9; duration: Tokens.motion.slow * 2; easing.type: Tokens.motion.easeOut }
            NumberAnimation { from: 1.9; to: 1.0; duration: Tokens.motion.slow * 2; easing.type: Tokens.motion.easeIn }
        }
        SequentialAnimation on opacity {
            running: halo.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.45; to: 0.0; duration: Tokens.motion.slow * 2; easing.type: Tokens.motion.easeOut }
            NumberAnimation { from: 0.0; to: 0.45; duration: Tokens.motion.slow * 2; easing.type: Tokens.motion.easeIn }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: Tokens.radius.pill
        color: root.dotColor
    }
}
