import QtQuick
import "../Theme"

Rectangle {
    id: root

    property bool active: false
    property bool keyboardOnly: true
    property real ringRadius: Tokens.radius.sm
    property real outset: Tokens.px(1)
    property real ringWidth: Tokens.hairlineWidth

    anchors.fill: parent
    anchors.margins: -root.outset
    visible: opacity > 0
    opacity: (root.active && (!root.keyboardOnly || Tokens.keyboardNavigation)) ? 1 : 0
    radius: root.ringRadius > 0 ? root.ringRadius + root.outset : 0
    color: "transparent"
    border.width: root.ringWidth
    border.color: Tokens.color.focusRing
    z: 10

    Accessible.ignored: true

    Behavior on opacity {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
    }
}
