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

    preferredWidth: 560
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

    function displayNameOf(d: var): string {
        if (!d) return ""
        return d.name || d.deviceName || d.address || ""
    }

    function groupOf(d: var): string {
        if (!d) return "nearby"
        if (d.connected) return "connected"
        return (d.paired || d.bonded) ? "paired" : "nearby"
    }

    function groupLabel(g: string): string {
        if (g === "connected") return qsTr("CONNECTED")
        if (g === "paired") return qsTr("PAIRED")
        return qsTr("NEARBY")
    }

    readonly property var all: Bt.hasAdapter
        ? Bt.devices.filter(d => nameOf(d) !== "" || (d.address && d.address !== ""))
        : []
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
        if (nameOf(d) === "" && d.address)
            return d.address
        return ""
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

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Bluetooth")
            icon: Bt.enabled ? "bluetooth" : "bluetooth-off"
            detail: !Bt.hasAdapter
                ? qsTr("Adapter unavailable")
                : (!Bt.enabled ? qsTr("Radio off") : "")
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

    // ── GROUPED DEVICES LIST ────────────────────────────────────────────────────
    Surface {
        visible: Bt.hasAdapter && Bt.enabled && root.flat.length > 0
        width: parent.width
        role: "card"
        horizontalPadding: Tokens.space.sm
        verticalPadding: Tokens.space.sm
        radius: Tokens.radius.md
        implicitHeight: Math.min(Tokens.px(48) * 5, btList.contentHeight) + verticalPadding * 2

        ListView {
            id: btList

            anchors.fill: parent
            spacing: 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.flat

            delegate: Item {
                id: devRow

                required property var modelData
                required property int index

                readonly property bool isPaired: devRow.modelData.paired || devRow.modelData.bonded
                readonly property bool hasBat: devRow.modelData.batteryAvailable === true
                readonly property int batPct: hasBat ? Math.round(devRow.modelData.battery * 100) : 0
                readonly property string sectionGroup: root.groupOf(devRow.modelData)
                readonly property bool isFirstInGroup: devRow.index === 0
                    || (devRow.index > 0 && root.groupOf(root.flat[devRow.index - 1]) !== devRow.sectionGroup)
                readonly property string subText: root.statusOf(devRow.modelData)
                readonly property bool hasSubtitle: devRow.subText !== ""
                readonly property color batTint: batPct <= 20
                    ? Tokens.color.danger
                    : (batPct <= 40 ? Tokens.color.warning : Tokens.color.success)

                width: btList.width
                implicitHeight: devOuterCol.implicitHeight

                // Hairline divider between rows within a group
                Rectangle {
                    visible: devRow.index > 0 && !devRow.isFirstInGroup
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Tokens.space.md
                    anchors.rightMargin: Tokens.space.md
                    height: Tokens.hairlineWidth
                    color: Tokens.color.hairline
                }

                ColumnLayout {
                    id: devOuterCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.space.xs

                    // Section label when starting a group
                    TextLabel {
                        visible: devRow.isFirstInGroup
                        Layout.fillWidth: true
                        Layout.leftMargin: Tokens.space.md
                        Layout.topMargin: devRow.index > 0 ? Tokens.space.sm : Tokens.space.xs
                        role: "caption"
                        tone: "muted"
                        font.weight: Font.Medium
                        text: root.groupLabel(devRow.sectionGroup)
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: devRow.hasSubtitle ? Tokens.px(56) : Tokens.px(48)

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: (devRow.index > 0 && !devRow.isFirstInGroup) ? Tokens.space.xxs : 0
                            anchors.bottomMargin: Tokens.space.xxs
                            radius: Tokens.radius.sm
                            color: (rowHover.hovered || root.sel === devRow.index)
                                ? Tokens.veilHoverOf(Tokens.surfaceStyle)
                                : "transparent"

                            Behavior on color {
                                enabled: !Tokens.reducedMotion && !Tokens.gameMode
                                ColorAnimation { duration: Tokens.motion.fast }
                            }
                        }

                        FocusRing {
                            active: root.sel === devRow.index
                            ringRadius: Tokens.radius.sm
                        }

                        RowLayout {
                            id: devRowLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.px(14)
                            anchors.rightMargin: Tokens.px(14)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.space.sm

                            Icon {
                                icon: root.iconOf(devRow.modelData)
                                size: Tokens.size.iconMd
                                tone: devRow.modelData.connected ? "accent" : "primary"
                                framed: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.space.xxs

                                TextLabel {
                                    Layout.fillWidth: true
                                    role: "body"
                                    font.weight: devRow.modelData.connected ? Font.Medium : Font.Normal
                                    tone: devRow.modelData.connected ? "accent" : "primary"
                                    text: root.displayNameOf(devRow.modelData)
                                }

                                TextLabel {
                                    visible: devRow.subText !== ""
                                    Layout.fillWidth: true
                                    role: "caption"
                                    tone: root.isPending(devRow.modelData) ? "warning" : "muted"
                                    tabular: true
                                    text: devRow.subText
                                }
                            }

                            // Single clean battery % pill
                            Rectangle {
                                visible: devRow.hasBat
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: batPillRow.implicitWidth + Tokens.space.sm * 2
                                implicitHeight: batPillRow.implicitHeight + Tokens.space.xxs * 2
                                radius: Tokens.radius.pill
                                color: Qt.rgba(devRow.batTint.r, devRow.batTint.g, devRow.batTint.b, 0.14)
                                border.width: Tokens.hairlineWidth
                                border.color: Qt.rgba(devRow.batTint.r, devRow.batTint.g, devRow.batTint.b, 0.30)

                                RowLayout {
                                    id: batPillRow
                                    anchors.centerIn: parent
                                    spacing: Tokens.space.xxs

                                    Icon {
                                        name: "battery"
                                        size: Tokens.size.iconXs
                                        customColor: devRow.batTint
                                    }

                                    TextLabel {
                                        role: "caption"
                                        tabular: true
                                        font.weight: Font.Medium
                                        color: devRow.batTint
                                        text: devRow.batPct + "%"
                                    }
                                }
                            }

                            Badge {
                                visible: devRow.modelData.connected && !root.isPending(devRow.modelData)
                                text: qsTr("Connected")
                                tone: "accent"
                            }

                            Button {
                                text: devRow.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
                                variant: devRow.modelData.connected ? "ghost" : "primary"
                                size: "sm"
                                loading: root.isPending(devRow.modelData)
                                accessibleLabel: devRow.modelData.connected
                                    ? qsTr("Disconnect %1").arg(root.displayNameOf(devRow.modelData))
                                    : qsTr("Connect %1").arg(root.displayNameOf(devRow.modelData))
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
                                accessibleLabel: qsTr("Forget %1").arg(root.displayNameOf(devRow.modelData))
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
