import QtQuick
import "../Theme"
import "../Primitives"

Item {
    id: root

    property bool open: false
    property bool splitBlur: false
    property real splitRatio: 0.42
    default property alias content: drawer.content

    signal dismissed()

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1.0 : 0.0

    Behavior on opacity {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        NumberAnimation { duration: Tokens.motion.normal; easing.type: Tokens.motion.easeOut }
    }

    Rectangle {
        anchors.fill: parent
        color: Tokens.color.scrim

        TapHandler {
            onTapped: root.dismissed()
        }
    }

    Surface {
        id: drawer

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: root.splitBlur ? 0 : Tokens.space.lg
        width: root.splitBlur ? parent.width * root.splitRatio : Tokens.size.panelSm
        role: "ground"
        radius: root.splitBlur ? Tokens.radius.none : Tokens.radius.lg
        horizontalPadding: Tokens.space.xxl
        verticalPadding: Tokens.space.xl
    }
}
