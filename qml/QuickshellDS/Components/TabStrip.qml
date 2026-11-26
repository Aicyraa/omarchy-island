pragma ComponentBehavior: Bound

import QtQuick
import "../Theme"
import "../Primitives"

Item {
    id: root

    property var tabs: [] // [{ id, label }]
    property string current: ""
    property string accessibleLabel: qsTr("Tabs")

    signal picked(string id)

    implicitWidth: row.implicitWidth + Tokens.space.xs
    implicitHeight: root.tabs.length > 1 ? Tokens.size.controlSm + Tokens.space.xxs : 0
    visible: root.tabs.length > 1
    activeFocusOnTab: root.enabled && root.visible

    Accessible.role: Accessible.PageTabList
    Accessible.name: root.accessibleLabel

    function stepTab(delta: int): void {
        if (root.tabs.length === 0)
            return
        const idx = root.tabs.findIndex(t => t.id === root.current)
        const next = (Math.max(0, idx) + delta + root.tabs.length) % root.tabs.length
        root.picked(root.tabs[next].id)
    }

    FocusRing {
        active: root.activeFocus
        ringRadius: Tokens.radius.pill
    }

    Row {
        id: row

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.xs

        Repeater {
            model: root.tabs

            Rectangle {
                id: tabPill

                required property var modelData
                readonly property bool isActive: tabPill.modelData.id === root.current

                width: tabLabel.implicitWidth + Tokens.space.lg * 1.5
                height: Tokens.size.controlSm - Tokens.space.xxs
                radius: Tokens.radius.pill
                color: tabPill.isActive
                    ? Tokens.color.accent
                    : (tabHover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : Tokens.veilOf(Tokens.surfaceStyle))
                border.width: Tokens.hairlineWidth
                border.color: tabPill.isActive ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

                Behavior on color {
                    enabled: !Tokens.reducedMotion && !Tokens.gameMode
                    ColorAnimation { duration: Tokens.motion.fast }
                }

                TextLabel {
                    id: tabLabel

                    anchors.centerIn: parent
                    role: "sm"
                    tone: tabPill.isActive ? "onAccent" : "muted"
                    font.weight: tabPill.isActive ? Font.Medium : Font.Normal
                    text: tabPill.modelData.label ?? ""
                }

                HoverHandler {
                    id: tabHover

                    enabled: root.enabled
                    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                    enabled: root.enabled
                    onTapped: {
                        Tokens.keyboardNavigation = false
                        root.picked(tabPill.modelData.id)
                    }
                }
            }
        }
    }

    Keys.onLeftPressed: if (root.enabled) root.stepTab(-1)
    Keys.onRightPressed: if (root.enabled) root.stepTab(1)
}
