import QtQuick
import "../Theme"
import "../Primitives"

Surface {
    id: root

    property string text: ""
    property bool shown: false

    role: "ground"
    sheen: false
    radius: Tokens.radius.pill
    implicitWidth: label.implicitWidth + Tokens.space.lg
    implicitHeight: label.implicitHeight + Tokens.space.xs * 2
    visible: opacity > 0
    opacity: root.shown && root.text !== "" ? 1.0 : 0.0
    z: 50

    Accessible.ignored: true

    Behavior on opacity {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
    }

    TextLabel {
        id: label

        anchors.centerIn: parent
        role: "sm"
        tone: "primary"
        font.weight: Font.Medium
        text: root.text
    }
}
