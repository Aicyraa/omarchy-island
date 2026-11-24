pragma ComponentBehavior: Bound

import QtQuick
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property bool checked: false
    property string accessibleLabel: qsTr("Toggle")

    signal toggled(bool checked)

    implicitWidth: Tokens.px(40)
    implicitHeight: Tokens.px(22)
    radius: Tokens.radius.pill
    opacity: root.enabled ? 1.0 : 0.45
    activeFocusOnTab: root.enabled

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.accessibleLabel
    Accessible.checked: root.checked

    color: root.checked ? Tokens.color.accent : Tokens.veilHoverOf(Tokens.surfaceStyle)
    border.width: Tokens.hairlineWidth
    border.color: root.checked ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

    Behavior on color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }
    Behavior on border.color {
        enabled: !Tokens.reducedMotion && !Tokens.gameMode
        ColorAnimation { duration: Tokens.motion.fast }
    }

    FocusRing {
        active: root.activeFocus
        ringRadius: Tokens.radius.pill
    }

    Rectangle {
        readonly property real pad: Tokens.px(3)

        y: pad
        x: root.checked ? root.width - width - pad : pad
        width: root.height - pad * 2
        height: width
        radius: Tokens.radius.pill
        color: root.checked ? Tokens.color.onAccent : Tokens.color.textMuted

        Behavior on x {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
        }
        Behavior on color {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            ColorAnimation { duration: Tokens.motion.fast }
        }
    }

    HoverHandler {
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: {
            Tokens.keyboardNavigation = false
            root.toggled(!root.checked)
        }
    }

    Keys.onSpacePressed: {
        if (root.enabled)
            root.toggled(!root.checked)
    }
    Keys.onReturnPressed: {
        if (root.enabled)
            root.toggled(!root.checked)
    }
}
