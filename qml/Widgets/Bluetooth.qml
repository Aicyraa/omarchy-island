pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"

WidgetSurface {
    id: root

    preferredWidth: 560
    useReserve: false
    scrollTarget: (Bt.hasAdapter && Bt.enabled && root.listDevices.length > 0) ? btList : null
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
    readonly property var primaryConnected: connected.length > 0 ? connected[0] : null
    readonly property var listDevices: connected.slice(1).concat(paired).concat(available)
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
            root.sel = Math.min(root.sel + 1, Math.max(0, root.listDevices.length - 1))
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.sel = Math.max(root.sel - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.listDevices[root.sel])
                root.toggleDevice(root.listDevices[root.sel])
            event.accepted = true
        } else if (event.key === Qt.Key_B) {
            Bt.toggle()
            event.accepted = true
        } else if (event.key === Qt.Key_S) {
            root.scan()
            event.accepted = true
        }
    }

    // ── TOP CONNECTED SECTION + ACTION CONTROLS ─────────────────────────────────
    RowLayout {
        width: parent.width
        spacing: Tokens.space.md

        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: connectedRow.visible ? connectedRow.implicitHeight : idleRow.implicitHeight

            RowLayout {
                id: idleRow
                visible: !(Bt.hasAdapter && Bt.enabled && root.primaryConnected !== null)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.space.md

                Icon {
                    icon: (!Bt.hasAdapter || !Bt.enabled) ? "bluetooth-off" : "bluetooth"
                    size: Tokens.size.iconXl
                    tone: "muted"
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xxs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "subtitle"
                        font.weight: Font.Medium
                        tone: "secondary"
                        text: !Bt.hasAdapter
                            ? qsTr("No Bluetooth adapter")
                            : (!Bt.enabled ? qsTr("Bluetooth is off") : qsTr("Not connected"))
                        textFormat: Text.PlainText
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        text: !Bt.hasAdapter
                            ? qsTr("Adapter unavailable")
                            : (!Bt.enabled
                                ? qsTr("Turn on Bluetooth to connect devices")
                                : (root.discovering ? qsTr("Scanning for devices…") : qsTr("Select a device below to connect")))
                        textFormat: Text.PlainText
                    }
                }
            }

            RowLayout {
                id: connectedRow
                visible: Bt.hasAdapter && Bt.enabled && root.primaryConnected !== null
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.space.md

                Icon {
                    icon: root.iconOf(root.primaryConnected)
                    size: Tokens.size.iconXl
                    tone: "accent"
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.sm

                        TextLabel {
                            Layout.fillWidth: true
                            role: "subtitle"
                            font.weight: Font.Medium
                            singleLine: true
                            elide: Text.ElideRight
                            text: root.displayNameOf(root.primaryConnected)
                            textFormat: Text.PlainText
                        }

                        TextLabel {
                            readonly property bool hasBat: root.primaryConnected !== null && root.primaryConnected.batteryAvailable === true
                            readonly property int batPct: hasBat ? Math.round(root.primaryConnected.battery * 100) : 0
                            role: "sm"
                            tabular: true
                            tone: hasBat
                                ? (batPct > 40 ? "accent" : (batPct > 20 ? "warning" : "danger"))
                                : "accent"
                            font.weight: Font.Medium
                            text: hasBat ? (batPct + "%") : qsTr("Connected")
                            textFormat: Text.PlainText
                        }
                    }

                    // Ascending 36-bar vertical battery graph visualizer
                    Item {
                        id: btBatGraph

                        readonly property int barCount: 36
                        readonly property real level: (root.primaryConnected !== null && root.primaryConnected.batteryAvailable === true)
                            ? Math.max(0, Math.min(1, root.primaryConnected.battery)) : 0
                        readonly property color litColor: level > 0.4
                            ? Tokens.color.accent
                            : (level > 0.2 ? Tokens.color.warning : Tokens.color.danger)

                        visible: root.primaryConnected !== null && root.primaryConnected.batteryAvailable === true
                        Layout.fillWidth: true
                        Layout.preferredHeight: Tokens.px(12)

                        Repeater {
                            model: btBatGraph.barCount

                            Rectangle {
                                id: btBatBar

                                required property int index

                                readonly property real frac: btBatGraph.barCount > 1
                                    ? index / (btBatGraph.barCount - 1) : 1.0
                                readonly property bool lit: (index + 0.5) / btBatGraph.barCount <= btBatGraph.level

                                width: Tokens.px(3)
                                height: Math.max(Tokens.px(3), Math.round(Tokens.px(3) + (btBatGraph.height - Tokens.px(3)) * btBatBar.frac))
                                x: btBatGraph.barCount > 1
                                    ? Math.round(btBatBar.frac * Math.max(0, btBatGraph.width - btBatBar.width))
                                    : 0
                                anchors.bottom: parent.bottom
                                radius: Tokens.radius.pill
                                color: btBatBar.lit ? btBatGraph.litColor : Tokens.veilHoverOf(Tokens.surfaceStyle)

                                Behavior on color {
                                    enabled: !Tokens.reducedMotion && !Tokens.gameMode
                                    ColorAnimation { duration: Tokens.motion.fast }
                                }
                            }
                        }
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: root.isPending(root.primaryConnected) ? "warning" : "muted"
                        tabular: true
                        singleLine: true
                        elide: Text.ElideRight
                        text: {
                            const sub = root.statusOf(root.primaryConnected)
                            if (sub !== "")
                                return sub
                            if (root.connected.length > 1)
                                return qsTr("Connected") + " · " + qsTr("+%1 more").arg(root.connected.length - 1)
                            return qsTr("Connected") + (root.primaryConnected && root.primaryConnected.address ? " · " + root.primaryConnected.address : "")
                        }
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        Rectangle {
            visible: Bt.hasAdapter
            Layout.preferredWidth: Tokens.hairlineWidth
            Layout.fillHeight: true
            Layout.topMargin: Tokens.space.xs
            Layout.bottomMargin: Tokens.space.xs
            color: Tokens.color.hairline
        }

        ColumnLayout {
            id: rightCtrlCol

            visible: Bt.hasAdapter
            Layout.fillWidth: false
            Layout.preferredWidth: topCtrlRow.implicitWidth
            Layout.minimumWidth: topCtrlRow.implicitWidth
            Layout.maximumWidth: topCtrlRow.implicitWidth
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: Tokens.space.sm

            RowLayout {
                id: topCtrlRow

                Layout.alignment: Qt.AlignRight
                spacing: Tokens.space.sm

                Button {
                    icon: "refresh-cw"
                    variant: "elevated"
                    shape: "circle"
                    size: "sm"
                    enabled: Bt.enabled
                    accessibleLabel: qsTr("Scan for Bluetooth devices")
                    onClicked: root.scan()
                }

                ToggleSwitch {
                    checked: Bt.enabled
                    accessibleLabel: qsTr("Toggle Bluetooth")
                    onToggled: Bt.toggle()
                }
            }

            Button {
                visible: Bt.enabled && root.primaryConnected !== null
                Layout.fillWidth: true
                icon: "unlink"
                variant: "dangerSubtle"
                shape: "pill"
                size: "sm"
                loading: root.isPending(root.primaryConnected)
                accessibleLabel: qsTr("Disconnect %1").arg(root.displayNameOf(root.primaryConnected))
                onClicked: root.toggleDevice(root.primaryConnected)
            }
        }
    }

    // ── GROUPED DEVICES LIST (borderless container, soft list items) ────────────
    Item {
        visible: Bt.hasAdapter && Bt.enabled && root.listDevices.length > 0
        width: parent.width
        implicitHeight: Math.min(Tokens.px(72) * 4 + Tokens.space.sm * 3, btList.contentHeight)

        ListView {
            id: btList

            anchors.fill: parent
            spacing: Tokens.space.sm
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.listDevices

            delegate: Item {
                id: devRow

                required property var modelData
                required property int index

                readonly property bool isPaired: devRow.modelData.paired || devRow.modelData.bonded
                readonly property bool hasBat: devRow.modelData.batteryAvailable === true
                readonly property int batPct: hasBat ? Math.round(devRow.modelData.battery * 100) : 0
                readonly property string sectionGroup: root.groupOf(devRow.modelData)
                readonly property bool isFirstInGroup: devRow.index === 0
                    || (devRow.index > 0 && root.groupOf(root.listDevices[devRow.index - 1]) !== devRow.sectionGroup)
                readonly property string subText: root.statusOf(devRow.modelData)
                readonly property bool hasSubtitle: devRow.subText !== ""
                readonly property color batTint: batPct <= 20
                    ? Tokens.color.danger
                    : (batPct <= 40 ? Tokens.color.warning : Tokens.color.success)

                width: btList.width
                implicitHeight: devOuterCol.implicitHeight

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
                        implicitHeight: Tokens.px(72)

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius.md
                            border.width: 0
                            border.color: "transparent"
                            color: devRow.modelData.connected
                                ? Tokens.color.accentMuted
                                : ((rowHover.hovered || root.sel === devRow.index)
                                    ? Tokens.veilHoverOf(Tokens.surfaceStyle)
                                    : Tokens.veilOf(Tokens.surfaceStyle))

                            Behavior on color {
                                enabled: !Tokens.reducedMotion && !Tokens.gameMode
                                ColorAnimation { duration: Tokens.motion.fast }
                            }
                        }

                        FocusRing {
                            active: root.sel === devRow.index
                            ringRadius: Tokens.radius.md
                        }

                        RowLayout {
                            id: devRowLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.space.lg
                            anchors.rightMargin: Tokens.space.lg
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.space.md

                            Icon {
                                icon: root.iconOf(devRow.modelData)
                                size: Tokens.size.iconLg
                                tone: devRow.modelData.connected ? "accent" : "primary"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.space.xxs

                                TextLabel {
                                    Layout.fillWidth: true
                                    role: "body"
                                    font.weight: Font.Medium
                                    tone: devRow.modelData.connected ? "accent" : "primary"
                                    text: root.displayNameOf(devRow.modelData)
                                }

                                TextLabel {
                                    Layout.fillWidth: true
                                    role: "caption"
                                    tone: root.isPending(devRow.modelData) ? "warning" : "muted"
                                    tabular: true
                                    text: devRow.subText !== ""
                                        ? devRow.subText
                                        : (devRow.isPaired
                                            ? qsTr("Paired")
                                            : (devRow.modelData.address || qsTr("Available")))
                                }
                            }

                            Button {
                                visible: devRow.isPaired && rowHover.hovered
                                icon: "trash-2"
                                variant: "ghost"
                                size: "sm"
                                accessibleLabel: qsTr("Forget %1").arg(root.displayNameOf(devRow.modelData))
                                onClicked: root.forgetDevice(devRow.modelData)
                            }

                            Button {
                                icon: devRow.modelData.connected ? "unlink" : "link"
                                variant: devRow.modelData.connected ? "dangerSubtle" : "ghost"
                                shape: "circle"
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
    TextLabel {
        visible: Bt.hasAdapter && Bt.enabled && root.connected.length > 0 && root.listDevices.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        role: "caption"
        tone: "muted"
        text: root.discovering ? qsTr("Scanning for other devices…") : qsTr("No other devices nearby")
        textFormat: Text.PlainText
    }

    EmptyState {
        visible: !Bt.hasAdapter || !Bt.enabled || (root.connected.length === 0 && root.listDevices.length === 0)
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
