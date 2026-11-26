pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Theme"
import "../Primitives"
import "../Components"

PanelWindow {
    id: root

    property bool live: true
    property bool expanded: false
    property bool notched: false
    property real topMargin: Tokens.space.lg

    property real targetWidth: Tokens.px(220)
    property real targetHeight: Tokens.size.barHeight
    property real targetRadius: Tokens.radius.pill

    property ScrollRail attachedRail: null
    default property alias content: body.data

    signal dismissed()

    readonly property bool holdsKeyboard: root.live && root.expanded

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: root.screen ? root.screen.height : Tokens.px(1080)
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "quickshellds-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.holdsKeyboard
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.holdsKeyboard
        windows: [root]
        onCleared: root.dismissed()
    }

    mask: Region {
        Region {
            x: capsule.x
            y: capsule.y
            width: capsule.width
            height: capsule.height + Tokens.space.md
        }

        Region {
            x: root.attachedRail ? root.attachedRail.inputRect.x : 0
            y: root.attachedRail ? root.attachedRail.inputRect.y : 0
            width: root.attachedRail ? root.attachedRail.inputRect.width : 0
            height: root.attachedRail ? root.attachedRail.inputRect.height : 0
        }
    }

    Surface {
        id: capsule

        x: (root.width - width) / 2
        y: root.notched ? 0 : root.topMargin
        width: root.targetWidth
        height: root.targetHeight + (root.notched ? root.topMargin : 0)
        role: "ground"
        radius: root.targetRadius
        topLeftRadius: root.notched ? 0 : root.targetRadius
        topRightRadius: root.notched ? 0 : root.targetRadius

        Behavior on width {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.morph; easing.type: Tokens.motion.easeOut }
        }
        Behavior on height {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.morph; easing.type: Tokens.motion.easeOut }
        }
        Behavior on radius {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.morph; easing.type: Tokens.motion.easeOut }
        }

        Item {
            id: body

            anchors.fill: parent
            anchors.topMargin: root.notched ? root.topMargin : 0
        }
    }

    Repeater {
        model: root.notched ? [true, false] : []

        NotchFillet {
            required property bool modelData

            x: modelData ? capsule.x - width : capsule.x + capsule.width
            y: 0
            mirrored: modelData
        }
    }
}
