pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 600
    readonly property bool capturesEscape: root.pendingIndex >= 0
    hint: root.pendingIndex >= 0
        ? qsTr("Enter confirm · Esc cancel")
        : qsTr("1-%1 pick · ←/→ move · Enter confirm · Esc close").arg(root.visibleActions.length)

    property int sel: 0
    property int pendingIndex: -1
    property bool hibernateAvailable: false
    property bool restartNeeded: false

    readonly property var sessionActions: {
        const list = [
            { icon: "lock",       title: qsTr("Lock"),        destructive: false, cmd: ["omarchy-system-lock"] },
            { icon: "moon",       title: qsTr("Suspend"),     destructive: false, cmd: ["bash", "-c", "omarchy-system-lock; systemctl suspend"] }
        ]
        if (root.hibernateAvailable)
            list.push({ icon: "hard-drive", title: qsTr("Hibernate"), destructive: false, cmd: ["bash", "-c", "omarchy-system-lock; systemctl hibernate"] })
        list.push(
            { icon: "log-out",    title: qsTr("Logout"),      destructive: false, cmd: ["omarchy-system", "logout"] },
            { icon: "eye",        title: qsTr("Screensaver"), destructive: false, cmd: ["omarchy-launch-screensaver", "force"] }
        )
        return list
    }

    readonly property var destructiveActions: [
        { icon: "rotate-ccw", title: qsTr("Reboot"),   destructive: true, cmd: ["omarchy-system", "reboot"] },
        { icon: "power",      title: qsTr("Shutdown"), destructive: true, cmd: ["omarchy-system", "shutdown"] }
    ]

    readonly property var visibleActions: root.sessionActions.concat(root.destructiveActions)

    function executeAction(idx: int): void {
        if (idx < 0 || idx >= root.visibleActions.length)
            return
        const act = root.visibleActions[idx]
        root.pendingIndex = -1
        Cmd.run(act.cmd)
        IslandState.closeWidget()
    }

    function triggerAction(idx: int): void {
        if (idx < 0 || idx >= root.visibleActions.length)
            return
        const act = root.visibleActions[idx]
        root.sel = idx
        if (act.destructive) {
            root.pendingIndex = idx
            Qt.callLater(function () { confirmBtn.forceActiveFocus() })
        } else {
            root.executeAction(idx)
        }
    }

    Keys.onPressed: function (e) {
        if (root.pendingIndex >= 0) {
            if (e.key === Qt.Key_Escape) {
                root.pendingIndex = -1
                root.forceActiveFocus()
                e.accepted = true
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.executeAction(root.pendingIndex)
                e.accepted = true
            }
            return
        }
        const n = root.visibleActions.length
        if (e.key >= Qt.Key_1 && e.key < Qt.Key_1 + n) {
            root.triggerAction(e.key - Qt.Key_1)
            e.accepted = true
        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) {
            root.sel = (root.sel + n - 1) % n
            e.accepted = true
        } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
            root.sel = (root.sel + 1) % n
            e.accepted = true
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            root.triggerAction(root.sel)
            e.accepted = true
        }
    }

    component ActionTile: Surface {
        id: tile

        required property var actionData
        required property int globalIndex

        readonly property bool isSelected: root.sel === tile.globalIndex
        readonly property bool isDestructive: !!tile.actionData.destructive

        Layout.fillWidth: true
        Layout.preferredHeight: tile.isDestructive ? Tokens.px(88) : Tokens.px(92)
        verticalPadding: Tokens.space.md
        role: "card"
        radius: Tokens.radius.md
        hovered: tileHover.hovered
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: String(tile.actionData.title ?? "")

        border.color: {
            if (tile.isSelected)
                return tile.isDestructive ? Tokens.color.danger : Tokens.color.accent
            return Tokens.veilBorderOf(Tokens.surfaceStyle)
        }

        onActiveFocusChanged: {
            if (tile.activeFocus)
                root.sel = tile.globalIndex
        }

        Keys.onReturnPressed: root.triggerAction(tile.globalIndex)
        Keys.onSpacePressed: root.triggerAction(tile.globalIndex)

        FocusRing {
            active: tile.activeFocus
            ringRadius: tile.radius
        }

        Keycap {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Tokens.space.sm
            anchors.rightMargin: Tokens.space.sm
            text: String(tile.globalIndex + 1)
            size: "sm"
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Tokens.space.sm * 2
            spacing: Tokens.space.xs

            Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: String(tile.actionData.icon ?? "")
                size: Tokens.size.iconLg
                framed: true
                tone: tile.isDestructive
                    ? "danger"
                    : (tile.isSelected ? "accent" : "primary")
            }

            TextLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                role: "sm"
                font.weight: Font.Medium
                tone: tile.isDestructive ? "danger" : "primary"
                text: String(tile.actionData.title ?? "")
            }
        }

        HoverHandler {
            id: tileHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.triggerAction(tile.globalIndex)
        }
    }

    Item {
        id: stage

        width: parent.width
        implicitHeight: root.pendingIndex >= 0 ? confirmCard.implicitHeight : mainCol.implicitHeight

        ColumnLayout {
            id: mainCol

            width: parent.width
            spacing: Tokens.space.md
            visible: opacity > 0
            opacity: root.pendingIndex < 0 ? 1.0 : 0.0

            Behavior on opacity {
                enabled: !Tokens.reducedMotion && !Tokens.gameMode
                NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                DetailHeader {
                    Layout.fillWidth: true
                    title: qsTr("Power")
                    icon: "power"
                    backable: false
                }

                Badge {
                    visible: root.restartNeeded
                    text: qsTr("Restart needed")
                    tone: "warning"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                Repeater {
                    model: root.sessionActions

                    delegate: ActionTile {
                        required property var modelData
                        required property int index

                        actionData: modelData
                        globalIndex: index
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                TextLabel {
                    role: "caption"
                    tone: "muted"
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    text: qsTr("System")
                }

                Separator {
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                Repeater {
                    model: root.destructiveActions

                    delegate: ActionTile {
                        required property var modelData
                        required property int index

                        actionData: modelData
                        globalIndex: root.sessionActions.length + index
                    }
                }
            }
        }

        Card {
            id: confirmCard

            width: parent.width
            implicitHeight: confirmBody.implicitHeight + verticalPadding * 2
            visible: opacity > 0
            opacity: root.pendingIndex >= 0 ? 1.0 : 0.0

            Behavior on opacity {
                enabled: !Tokens.reducedMotion && !Tokens.gameMode
                NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
            }

            ColumnLayout {
                id: confirmBody

                width: parent.width
                spacing: Tokens.space.md

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.md

                    Icon {
                        icon: root.pendingIndex >= 0 ? String(root.visibleActions[root.pendingIndex].icon ?? "power") : "power"
                        size: Tokens.size.iconLg
                        tone: "danger"
                        framed: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xxs

                        TextLabel {
                            Layout.fillWidth: true
                            role: "title"
                            font.weight: Font.Medium
                            text: root.pendingIndex >= 0
                                ? qsTr("%1 now?").arg(String(root.visibleActions[root.pendingIndex].title))
                                : ""
                        }

                        TextLabel {
                            Layout.fillWidth: true
                            singleLine: false
                            role: "sm"
                            tone: "muted"
                            text: qsTr("Unsaved work in open apps may be lost.")
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.sm

                    Item { Layout.fillWidth: true }

                    Button {
                        text: qsTr("Cancel")
                        variant: "secondary"
                        onClicked: {
                            root.pendingIndex = -1
                            root.forceActiveFocus()
                        }
                    }

                    Button {
                        id: confirmBtn

                        text: root.pendingIndex >= 0
                            ? String(root.visibleActions[root.pendingIndex].title)
                            : qsTr("Confirm")
                        variant: "danger"
                        onClicked: root.executeAction(root.pendingIndex)
                    }
                }
            }
        }
    }

    Process {
        running: true
        command: ["omarchy-hibernation-available"]
        onExited: function (code) {
            root.hibernateAvailable = (code === 0)
        }
    }

    Process {
        running: true
        command: ["bash", "-c", "[ -d /usr/lib/modules/$(uname -r) ] || echo restart"]
        stdout: StdioCollector {
            onStreamFinished: root.restartNeeded = text.indexOf("restart") >= 0
        }
    }
}
