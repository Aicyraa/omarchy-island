pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"

WidgetSurface {
    id: root

    preferredWidth: 680
    hint: qsTr("1-7 pick · ←/→ move · Enter confirm · Esc close")

    property int sel: 0
    property int pendingIndex: -1
    property bool hibernateAvailable: false
    property bool restartNeeded: false

    readonly property var actions: [
        { icon: "lock",       title: qsTr("Lock"),        destructive: false, available: true,                    cmd: ["omarchy-system-lock"] },
        { icon: "eye",        title: qsTr("Screensaver"), destructive: false, available: true,                    cmd: ["omarchy-launch-screensaver", "force"] },
        { icon: "moon",       title: qsTr("Suspend"),     destructive: false, available: true,                    cmd: ["bash", "-c", "omarchy-system-lock; systemctl suspend"] },
        { icon: "hard-drive", title: qsTr("Hibernate"),   destructive: false, available: root.hibernateAvailable, cmd: ["bash", "-c", "omarchy-system-lock; systemctl hibernate"] },
        { icon: "log-out",    title: qsTr("Logout"),      destructive: false, available: true,                    cmd: ["omarchy-system", "logout"] },
        { icon: "rotate-ccw", title: qsTr("Reboot"),      destructive: true,  available: true,                    cmd: ["omarchy-system", "reboot"] },
        { icon: "power",      title: qsTr("Shutdown"),    destructive: true,  available: true,                    cmd: ["omarchy-system", "shutdown"] }
    ]

    function executeAction(idx: int): void {
        if (idx < 0 || idx >= root.actions.length)
            return
        const act = root.actions[idx]
        if (!act.available)
            return
        root.pendingIndex = -1
        Cmd.run(act.cmd)
        IslandState.closeWidget()
    }

    function triggerAction(idx: int): void {
        if (idx < 0 || idx >= root.actions.length)
            return
        const act = root.actions[idx]
        if (!act.available)
            return
        root.sel = idx
        if (act.destructive)
            root.pendingIndex = idx
        else
            root.executeAction(idx)
    }

    Keys.onPressed: function (e) {
        if (root.pendingIndex >= 0)
            return
        const n = root.actions.length
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

    Item {
        id: stage

        width: parent.width
        implicitHeight: Math.max(mainCol.implicitHeight, confirmDialog.open ? Tokens.px(210) : 0)

        ColumnLayout {
            id: mainCol

            width: parent.width
            spacing: Tokens.space.md

            Badge {
                visible: root.restartNeeded
                text: qsTr("Restart needed")
                tone: "warning"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                Repeater {
                    model: root.actions

                    delegate: Surface {
                        id: tile

                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.sel === tile.index
                        readonly property bool isDestructive: !!tile.modelData.destructive
                        readonly property bool isAvailable: !!tile.modelData.available

                        Layout.fillWidth: true
                        Layout.preferredHeight: Tokens.px(102)
                        role: "card"
                        radius: Tokens.radius.md
                        hovered: tileHover.hovered
                        opacity: tile.isAvailable ? 1.0 : 0.42
                        border.color: {
                            if (tile.isSelected)
                                return tile.isDestructive ? Tokens.color.danger : Tokens.color.accent
                            return Tokens.veilBorderOf(Tokens.surfaceStyle)
                        }

                        FocusRing {
                            active: tile.activeFocus
                            ringRadius: tile.radius
                        }

                        Keycap {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: Tokens.space.xs
                            anchors.rightMargin: Tokens.space.xs
                            text: String(tile.index + 1)
                            size: "sm"
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.space.sm * 2
                            spacing: Tokens.space.xs

                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: String(tile.modelData.icon ?? "")
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
                                text: String(tile.modelData.title ?? "")
                            }
                        }

                        HoverHandler {
                            id: tileHover

                            enabled: tile.isAvailable
                            cursorShape: tile.isAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }

                        TapHandler {
                            enabled: tile.isAvailable
                            onTapped: root.triggerAction(tile.index)
                        }
                    }
                }
            }
        }

        ConfirmDialog {
            id: confirmDialog

            open: root.pendingIndex >= 0
            destructive: true
            title: root.pendingIndex >= 0
                ? qsTr("%1 now?").arg(String(root.actions[root.pendingIndex].title))
                : qsTr("Confirm")
            message: root.pendingIndex >= 0
                ? qsTr("This will immediately %1 the machine.").arg(String(root.actions[root.pendingIndex].title).toLowerCase())
                : ""
            confirmText: root.pendingIndex >= 0
                ? String(root.actions[root.pendingIndex].title)
                : qsTr("Confirm")
            cancelText: qsTr("Cancel")
            onConfirmed: root.executeAction(root.pendingIndex)
            onCancelled: root.pendingIndex = -1
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
