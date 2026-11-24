pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property var options: [] // [{ id, label, icon }]
    property string current: ""
    property bool labelled: false
    property bool stretch: false
    property string accessibleLabel: qsTr("Segmented control")

    signal selected(string id)

    property Item hoveredSegment: null
    property var hoveredOption: null
    property Item activeSegment: null

    implicitWidth: layout.implicitWidth + Tokens.space.xs * 2
    implicitHeight: Tokens.size.controlSm
    radius: Tokens.radius.sm
    opacity: root.enabled ? 1.0 : 0.45
    activeFocusOnTab: root.enabled

    color: Tokens.veilHoverOf(Tokens.surfaceStyle)
    border.width: Tokens.hairlineWidth
    border.color: Tokens.veilBorderOf(Tokens.surfaceStyle)

    Accessible.role: Accessible.RadioButton
    Accessible.name: root.accessibleLabel

    function stepSelection(delta: int): void {
        if (root.options.length === 0)
            return
        const idx = root.options.findIndex(o => o.id === root.current)
        const next = (Math.max(0, idx) + delta + root.options.length) % root.options.length
        root.selected(root.options[next].id)
    }

    FocusRing {
        active: root.activeFocus
        ringRadius: root.radius
    }

    Rectangle {
        id: activePill

        visible: root.activeSegment !== null
        x: root.activeSegment ? layout.x + root.activeSegment.x : 0
        y: layout.y
        width: root.activeSegment ? root.activeSegment.width : 0
        height: root.activeSegment ? root.activeSegment.height : 0
        radius: Tokens.innerRadius(root.radius, Tokens.space.xxs)
        color: Tokens.color.accent

        Behavior on x {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
        }
        Behavior on width {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
        }
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        width: root.stretch ? root.width - Tokens.space.xs * 2 : implicitWidth
        spacing: Tokens.space.xxs

        Repeater {
            model: root.options

            Rectangle {
                id: seg

                required property var modelData
                readonly property bool isActive: seg.modelData.id === root.current
                readonly property bool hasIcon: (seg.modelData.icon ?? "") !== ""
                readonly property bool iconOnly: seg.hasIcon && !root.labelled

                onIsActiveChanged: {
                    if (seg.isActive)
                        root.activeSegment = seg
                }
                Component.onCompleted: {
                    if (seg.isActive)
                        root.activeSegment = seg
                }

                Layout.preferredHeight: root.implicitHeight - Tokens.space.xs * 2
                Layout.fillWidth: root.stretch
                Layout.preferredWidth: seg.iconOnly
                    ? Layout.preferredHeight
                    : Math.max(Tokens.px(64), segContent.implicitWidth + Tokens.space.lg)
                radius: Tokens.innerRadius(root.radius, Tokens.space.xxs)

                color: seg.isActive
                    ? "transparent"
                    : (segHover.hovered ? Tokens.veilBorderOf(Tokens.surfaceStyle) : "transparent")

                Behavior on color {
                    enabled: !Tokens.reducedMotion && !Tokens.gameMode
                    ColorAnimation { duration: Tokens.motion.fast }
                }

                Row {
                    id: segContent

                    anchors.centerIn: parent
                    spacing: Tokens.space.xs

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: seg.hasIcon
                        size: Tokens.size.iconSm
                        tone: seg.isActive ? "onAccent" : (segHover.hovered ? "primary" : "muted")
                        icon: seg.modelData.icon ?? ""
                    }

                    TextLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !seg.iconOnly
                        role: "sm"
                        tone: seg.isActive ? "onAccent" : (segHover.hovered ? "primary" : "muted")
                        font.weight: seg.isActive ? Font.Medium : Font.Normal
                        text: seg.modelData.label ?? ""
                    }
                }

                HoverHandler {
                    id: segHover

                    enabled: root.enabled
                    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onHoveredChanged: {
                        if (hovered) {
                            root.hoveredSegment = seg
                            root.hoveredOption = seg.modelData
                        } else if (root.hoveredSegment === seg) {
                            root.hoveredSegment = null
                            root.hoveredOption = null
                        }
                    }
                }

                TapHandler {
                    enabled: root.enabled
                    onTapped: {
                        Tokens.keyboardNavigation = false
                        root.selected(seg.modelData.id)
                    }
                }
            }
        }
    }

    Tooltip {
        shown: root.hoveredOption !== null && !root.labelled && ((root.hoveredOption.icon ?? "") !== "")
        text: root.hoveredOption ? (root.hoveredOption.label ?? "") : ""
        x: root.hoveredSegment ? layout.x + root.hoveredSegment.x + (root.hoveredSegment.width - width) / 2 : 0
        y: -height - Tokens.space.xs
    }

    Keys.onLeftPressed: if (root.enabled) root.stepSelection(-1)
    Keys.onRightPressed: if (root.enabled) root.stepSelection(1)
}
