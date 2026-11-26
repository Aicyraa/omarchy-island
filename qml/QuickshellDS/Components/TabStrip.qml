pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Theme"
import "../Primitives"

Rectangle {
    id: root

    property var tabs: [] // [{ id, label }]
    property string current: ""
    property bool stretch: true
    property string accessibleLabel: qsTr("Tabs")

    signal picked(string id)

    property Item activeTabItem: null

    implicitWidth: row.implicitWidth + Tokens.space.xxs * 2
    implicitHeight: root.tabs.length > 1 ? Tokens.size.controlSm + Tokens.space.xxs * 2 : 0
    visible: root.tabs.length > 1
    radius: Tokens.radius.md
    opacity: root.enabled ? 1.0 : 0.45
    activeFocusOnTab: root.enabled && root.visible

    color: Tokens.veilOf(Tokens.surfaceStyle)
    border.width: Tokens.hairlineWidth
    border.color: Tokens.veilBorderOf(Tokens.surfaceStyle)

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
        ringRadius: root.radius
    }

    Rectangle {
        id: activePill

        visible: root.activeTabItem !== null && root.activeTabItem.width > 0
        x: root.activeTabItem ? row.x + root.activeTabItem.x : 0
        y: row.y
        width: root.activeTabItem ? root.activeTabItem.width : 0
        height: root.activeTabItem ? root.activeTabItem.height : 0
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
        id: row

        x: Tokens.space.xxs
        y: Tokens.space.xxs
        width: root.stretch ? Math.max(0, root.width - Tokens.space.xxs * 2) : implicitWidth
        height: Math.max(0, root.height - Tokens.space.xxs * 2)
        spacing: Tokens.space.xxs

        Repeater {
            model: root.tabs

            Rectangle {
                id: tabPill

                required property var modelData
                readonly property bool isActive: tabPill.modelData.id === root.current

                onIsActiveChanged: {
                    if (tabPill.isActive)
                        root.activeTabItem = tabPill
                    else if (root.activeTabItem === tabPill)
                        root.activeTabItem = null
                }
                Component.onCompleted: {
                    if (tabPill.isActive)
                        root.activeTabItem = tabPill
                }

                Layout.fillHeight: true
                Layout.fillWidth: root.stretch
                Layout.preferredWidth: root.stretch ? 1 : (tabLabel.implicitWidth + Tokens.space.lg * 1.5)
                radius: Tokens.innerRadius(root.radius, Tokens.space.xxs)
                color: tabPill.isActive
                    ? "transparent"
                    : (tabHover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : "transparent")

                Behavior on color {
                    enabled: !Tokens.reducedMotion && !Tokens.gameMode
                    ColorAnimation { duration: Tokens.motion.fast }
                }

                TextLabel {
                    id: tabLabel

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, Math.max(0, parent.width - Tokens.space.sm * 2))
                    horizontalAlignment: Text.AlignHCenter
                    role: "sm"
                    tone: tabPill.isActive ? "onAccent" : (tabHover.hovered ? "primary" : "muted")
                    font.weight: tabPill.isActive ? Font.Medium : Font.Normal
                    text: tabPill.modelData.label ?? ""
                    textFormat: Text.PlainText
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
