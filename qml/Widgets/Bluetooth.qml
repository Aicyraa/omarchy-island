pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 520
    useReserve: false
    scrollTarget: (Bt.hasAdapter && Bt.enabled && root.flat.length > 0) ? btList : null
    hint: qsTr("↑/↓ select · Enter connect/disconnect · B radio · S scan · Esc close")

    property int sel: 0
    property var pending: ({})

    function iconOf(d: var): string {
        const i = String(d && d.icon ? d.icon : "")
        if (i.indexOf("head") >= 0 || i.indexOf("audio") >= 0)
            return "headphones"
        return "bluetooth"
    }

    function nameOf(d: var): string {
        return d ? (d.name || d.deviceName || "") : ""
    }

    readonly property var all: Bt.hasAdapter ? Bt.devices.filter(d => nameOf(d) !== "") : []
    readonly property var connected: all.filter(d => d.connected)
    readonly property var paired: all.filter(d => !d.connected && (d.paired || d.bonded))
    readonly property var available: all.filter(d => !d.connected && !(d.paired || d.bonded))
    readonly property var flat: connected.concat(paired).concat(available)
    readonly property bool discovering: Bt.hasAdapter && Bt.adapter.discovering

    function isPending(d: var): bool {
        if (!d) return false
        return pending[d.address] === true
            || d.state === BluetoothDeviceState.Connecting
            || d.state === BluetoothDeviceState.Disconnecting
    }

    function statusOf(d: var): string {
        if (!d) return ""
        if (d.state === BluetoothDeviceState.Connecting || (pending[d.address] === true && !d.connected))
            return qsTr("Connecting…")
        if (d.state === BluetoothDeviceState.Disconnecting)
            return qsTr("Disconnecting…")
        if (d.connected)
            return qsTr("Connected")
        return (d.paired || d.bonded) ? qsTr("Paired") : qsTr("Available")
    }

    function toggleDevice(d: var): void {
        if (!d) return
        const p = Object.assign({}, pending)
        p[d.address] = true
        pending = p
        settle.restart()
        if (d.connected)
            d.disconnect()
        else
            d.connect()
    }

    function forgetDevice(d: var): void {
        if (!d) return
        if (typeof d.forget === "function")
            d.forget()
        else
            Cmd.run(["bluetoothctl", "remove", d.address])
    }

    function scan(): void {
        if (!Bt.enabled) return
        Bt.adapter.discovering = true
        scanTimer.restart()
    }

    Timer {
        id: settle
        interval: 8000
        onTriggered: root.pending = ({})
    }

    Timer {
        id: scanTimer
        interval: 15000
        onTriggered: if (Bt.hasAdapter) Bt.adapter.discovering = false
    }

    Component.onCompleted: scan()
    Component.onDestruction: if (Bt.hasAdapter) Bt.adapter.discovering = false

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            root.sel = Math.min(root.sel + 1, Math.max(0, root.flat.length - 1))
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.sel = Math.max(root.sel - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.flat[root.sel])
                root.toggleDevice(root.flat[root.sel])
            event.accepted = true
        } else if (event.key === Qt.Key_B) {
            Bt.toggle()
            event.accepted = true
        } else if (event.key === Qt.Key_S) {
            root.scan()
            event.accepted = true
        }
    }

    // ── HEADER ──────────────────────────────────────────────────────────────────
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        Icon {
            icon: Bt.enabled ? "bluetooth" : "bluetooth-off"
            size: Tokens.size.iconXl
            tone: Bt.connectedDevices.length > 0 ? "accent" : "muted"
            framed: true
        }

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Bluetooth")
            detail: !Bt.hasAdapter
                ? qsTr("No Bluetooth adapter")
                : (!Bt.enabled ? qsTr("Radio is off")
                    : (root.discovering ? qsTr("Scanning for devices…")
                        : qsTr("%1 connected · %2 paired").arg(root.connected.length).arg(root.paired.length)))
        }

        Button {
            visible: Bt.hasAdapter
            icon: "refresh-cw"
            variant: "secondary"
            size: "sm"
            enabled: Bt.enabled
            loading: root.discovering
            accessibleLabel: qsTr("Scan for Bluetooth devices")
            onClicked: root.scan()
        }

        ToggleSwitch {
            visible: Bt.hasAdapter
            checked: Bt.enabled
            accessibleLabel: qsTr("Toggle Bluetooth")
            onToggled: Bt.toggle()
        }
    }

    // ── DEVICES LIST ────────────────────────────────────────────────────────────
    ListView {
        id: btList

        visible: Bt.hasAdapter && Bt.enabled && root.flat.length > 0
        width: parent.width
        height: Math.min(contentHeight, Tokens.px(340))
        spacing: Tokens.space.xs
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.flat

        delegate: Card {
            id: devRow

            required property var modelData
            required property int index

            readonly property bool isPaired: devRow.modelData.paired || devRow.modelData.bonded
            readonly property bool hasBat: devRow.modelData.batteryAvailable === true
            readonly property int batPct: hasBat ? Math.round(devRow.modelData.battery * 100) : 0

            width: btList.width
            horizontalPadding: Tokens.space.lg
            verticalPadding: Tokens.space.md
            hovered: rowHover.hovered || root.sel === devRow.index
            implicitHeight: devRowLayout.implicitHeight + verticalPadding * 2

            FocusRing {
                active: root.sel === devRow.index
                ringRadius: devRow.radius
            }

            RowLayout {
                id: devRowLayout
                width: parent.width
                spacing: Tokens.space.md

                Icon {
                    icon: root.iconOf(devRow.modelData)
                    size: Tokens.size.iconMd
                    tone: devRow.modelData.connected ? "accent" : "primary"
                    framed: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xxs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        StatusDot {
                            tone: devRow.modelData.connected
                                ? "success"
                                : (root.isPending(devRow.modelData) ? "warning" : "muted")
                            pulse: root.isPending(devRow.modelData)
                            size: Tokens.px(7)
                        }

                        TextLabel {
                            Layout.fillWidth: true
                            role: "body"
                            font.weight: devRow.modelData.connected ? Font.Medium : Font.Normal
                            text: root.nameOf(devRow.modelData)
                        }
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        tabular: true
                        text: root.statusOf(devRow.modelData)
                            + (devRow.modelData.address ? " · " + devRow.modelData.address : "")
                    }
                }

                ColumnLayout {
                    visible: devRow.hasBat
                    spacing: Tokens.space.xxs
                    Layout.alignment: Qt.AlignVCenter

                    Badge {
                        Layout.alignment: Qt.AlignRight
                        text: devRow.batPct + "%"
                        tone: devRow.batPct <= 20 ? "danger" : (devRow.batPct <= 40 ? "warning" : "success")
                    }

                    UsageBar {
                        implicitWidth: Tokens.px(54)
                        progress: devRow.modelData.battery
                        fillColor: devRow.batPct <= 20 ? Tokens.color.danger : Tokens.color.success
                    }
                }

                Button {
                    text: devRow.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
                    variant: devRow.modelData.connected ? "secondary" : "primary"
                    size: "sm"
                    loading: root.isPending(devRow.modelData)
                    accessibleLabel: devRow.modelData.connected
                        ? qsTr("Disconnect %1").arg(root.nameOf(devRow.modelData))
                        : qsTr("Connect %1").arg(root.nameOf(devRow.modelData))
                    onClicked: {
                        root.sel = devRow.index
                        root.toggleDevice(devRow.modelData)
                    }
                }

                Button {
                    visible: devRow.isPaired
                    icon: "trash-2"
                    variant: "ghost"
                    size: "sm"
                    accessibleLabel: qsTr("Forget %1").arg(root.nameOf(devRow.modelData))
                    onClicked: root.forgetDevice(devRow.modelData)
                }
            }

            HoverHandler {
                id: rowHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    root.sel = devRow.index
                    root.reveal(devRow)
                }
            }
        }
    }

    // ── EMPTY STATES ────────────────────────────────────────────────────────────
    EmptyState {
        visible: !Bt.hasAdapter || !Bt.enabled || root.flat.length === 0
        width: parent.width
        icon: !Bt.hasAdapter || !Bt.enabled ? "bluetooth-off" : "bluetooth"
        title: !Bt.hasAdapter
            ? qsTr("No Bluetooth adapter")
            : (!Bt.enabled ? qsTr("Bluetooth is off")
                : (root.discovering ? qsTr("Scanning for devices…") : qsTr("No devices found")))
        description: !Bt.hasAdapter
            ? qsTr("No Bluetooth hardware was detected on this machine.")
            : (!Bt.enabled ? qsTr("Turn on Bluetooth to pair and connect devices.")
                : qsTr("Put your device in pairing mode and press Scan."))
    }
}
