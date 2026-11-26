pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking
import "../Core"
import "../Core/Visuals"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 560
    useReserve: false
    scrollTarget: (!root.sharing && Net.hasWifi && Net.enabled && root.availNets.length > 0) ? netList : null
    hint: qsTr("↑/↓ select · Enter connect · D disconnect · W radio · R rescan · Q share · Esc close")
    readonly property bool capturesEscape: root.sharing || root.passwordSsid !== ""

    property int sel: 0
    property var info: ({})
    property bool sharing: false
    property bool scanning: false
    property string passwordSsid: ""
    property string passwordError: ""
    property var qr: ({ rows: [], size: 0, ssid: "", error: "" })
    readonly property var nets: Net.networks
    readonly property var availNets: (Net.hasWifi && Net.enabled && Net.connected)
        ? root.nets.filter(n => !n.connected)
        : root.nets

    function band(f: var): string {
        const n = parseFloat(f)
        return isNaN(n) ? "" : (n >= 5900 ? "6 GHz" : n >= 4900 ? "5 GHz" : "2.4 GHz")
    }

    function quality(frac: real): string {
        return frac > 0.75 ? qsTr("Excellent")
            : frac > 0.5 ? qsTr("Good")
            : frac > 0.25 ? qsTr("Fair") : qsTr("Weak")
    }

    function secured(n: var): bool {
        return n && n.security !== WifiSecurityType.Open
    }

    function subtitleOf(n: var): string {
        return (n && n.known) ? qsTr("Saved") : ""
    }

    function connectNetwork(n: var): void {
        if (!n || n.connected) return
        if (n.known || !secured(n)) {
            passwordSsid = ""
            passwordError = ""
            n.connect()
        } else {
            passwordSsid = (passwordSsid === n.name) ? "" : n.name
            passwordError = ""
        }
    }

    function submitPassword(ssid: string, pw: string): void {
        if (!pw || pw.length === 0) {
            passwordError = qsTr("Password required")
            return
        }
        if (!ssid || ssid.charAt(0) === "-") {
            passwordError = qsTr("Invalid network name")
            return
        }
        passwordError = ""
        Cmd.runSecret(["nmcli", "device", "wifi", "connect", ssid, "password", pw])
        passwordSsid = ""
        root.forceActiveFocus()
    }

    function rescan(): void {
        if (!Net.enabled) return
        scanning = true
        Cmd.run(["nmcli", "dev", "wifi", "rescan"])
        scanDone.restart()
    }

    function toggleShare(): void {
        if (sharing) {
            sharing = false
            qrProc.running = false
            return
        }
        if (!Net.connected) return
        qr = ({ rows: [], size: 0, ssid: Net.ssid, error: "" })
        sharing = true
        qrProc.running = true
    }

    function takeIntent(): void {
        if (IslandState.intent !== "wifi-share" || !Net.connected) return
        IslandState.intent = ""
        if (!sharing) toggleShare()
    }

    function refreshInfo(): void {
        if (Net.connected && !infoProc.running)
            infoProc.running = true
    }

    Timer {
        id: scanDone
        interval: 2000
        onTriggered: root.scanning = false
    }

    Timer {
        id: initialScan
        interval: 150
        running: true
        onTriggered: root.rescan()
    }

    Timer {
        interval: 5000
        repeat: true
        running: Net.connected
        onTriggered: root.refreshInfo()
    }

    Process {
        id: qrProc
        command: ["omarchy-network-qr", "--meta"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text || "").trim().split(/\r?\n/).filter(l => l !== "")
                let ssid = Net.ssid
                if (lines.length > 0 && lines[0].indexOf("meta\t") === 0) {
                    const f = lines.shift().split("\t")
                    ssid = f.slice(3).join("\t") || ssid
                }
                const size = lines.length > 0 ? lines[0].length : 0
                let ok = size > 0 && size === lines.length
                for (let i = 0; ok && i < lines.length; i++) {
                    if (lines[i].length !== size || !/^[01]+$/.test(lines[i]))
                        ok = false
                }
                root.qr = ({
                    rows: ok ? lines : [],
                    size: ok ? size : 0,
                    ssid: ssid,
                    error: ok ? "" : qsTr("Could not make the code")
                })
            }
        }
        onExited: code => {
            if (code !== 0)
                root.qr = ({ rows: [], size: 0, ssid: Net.ssid, error: qsTr("Could not make the code") })
        }
    }

    Process {
        id: infoProc
        running: Net.connected
        command: ["omarchy-network-status", "--verbose"]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                String(text || "").split("\n").forEach(l => {
                    const t = l.split("\t")
                    if (t.length >= 2)
                        o[t[0]] = t[1]
                })
                root.info = o
            }
        }
    }

    Connections {
        target: IslandState
        function onIntentChanged() { root.takeIntent() }
    }

    Connections {
        target: Net
        function onConnectedChanged() {
            root.takeIntent()
            if (Net.connected) root.refreshInfo()
        }
    }

    onQrChanged: codeCanvas.requestPaint()

    Component.onCompleted: {
        if (Net.device) Net.device.scannerEnabled = true
        takeIntent()
    }
    Component.onDestruction: {
        if (Net.device) Net.device.scannerEnabled = false
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.sharing) {
            root.sharing = false
            qrProc.running = false
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape && root.passwordSsid !== "") {
            root.passwordSsid = ""
            root.passwordError = ""
            root.forceActiveFocus()
            event.accepted = true
            return
        }
        if (root.sharing || root.passwordSsid !== "") return

        if (event.key === Qt.Key_Q) {
            root.toggleShare()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            root.sel = Math.min(root.sel + 1, Math.max(0, root.availNets.length - 1))
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.sel = Math.max(root.sel - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.availNets[root.sel])
                root.connectNetwork(root.availNets[root.sel])
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            if (Net.active) Net.active.disconnect()
            event.accepted = true
        } else if (event.key === Qt.Key_W) {
            Net.toggle()
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            root.rescan()
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
            title: qsTr("Wi-Fi")
            icon: Net.enabled ? "wifi" : "wifi-off"
            detail: !Net.hasWifi
                ? qsTr("Adapter unavailable")
                : (!Net.enabled ? qsTr("Radio off") : "")
        }

        Button {
            visible: Net.hasWifi && Net.connected
            icon: "qr-code"
            variant: root.sharing ? "primary" : "secondary"
            size: "sm"
            accessibleLabel: qsTr("Share Wi-Fi QR code")
            onClicked: root.toggleShare()
        }

        Button {
            visible: Net.hasWifi
            icon: "refresh-cw"
            variant: "secondary"
            size: "sm"
            enabled: Net.enabled && !root.scanning
            loading: root.scanning
            accessibleLabel: qsTr("Rescan networks")
            onClicked: root.rescan()
        }

        ToggleSwitch {
            visible: Net.hasWifi
            checked: Net.enabled
            accessibleLabel: qsTr("Toggle Wi-Fi radio")
            onToggled: Net.toggle()
        }
    }

    // ── CONNECTED HERO CARD ─────────────────────────────────────────────────────
    Card {
        visible: Net.hasWifi && Net.enabled && Net.connected
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: heroCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: heroCol
            width: parent.width
            spacing: Tokens.space.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.md

                WifiIcon {
                    level: Net.strength
                    off: !Net.enabled
                    size: Tokens.size.iconXl
                    color: Tokens.color.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xxs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.sm

                        TextLabel {
                            Layout.fillWidth: true
                            role: "subtitle"
                            font.weight: Font.Medium
                            text: Net.ssid
                        }

                        TextLabel {
                            role: "sm"
                            tabular: true
                            tone: "accent"
                            font.weight: Font.Medium
                            text: Math.round(Net.strength * 100) + "%"
                        }
                    }

                    UsageBar {
                        Layout.fillWidth: true
                        progress: Net.strength
                        segmented: true
                        autoThreshold: true
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        tabular: true
                        text: root.quality(Net.strength)
                            + (root.info.ip ? " · " + root.info.ip : "")
                            + (root.band(root.info.freq) ? " · " + root.band(root.info.freq) : "")
                            + (root.info.bitrate ? " · " + String(root.info.bitrate).replace(" MBit/s", " Mb/s") : "")
                    }
                }

                Button {
                    text: qsTr("Disconnect")
                    variant: "danger"
                    size: "sm"
                    accessibleLabel: qsTr("Disconnect from Wi-Fi")
                    onClicked: if (Net.active) Net.active.disconnect()
                }
            }

            // Balanced side-by-side QR share view
            Rectangle {
                visible: root.sharing
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.hairlineWidth
                color: Tokens.color.hairline
            }

            RowLayout {
                visible: root.sharing
                Layout.fillWidth: true
                spacing: Tokens.space.lg

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Tokens.space.xs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "subtitle"
                        font.weight: Font.Medium
                        text: qsTr("Share Wi-Fi")
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "body"
                        tone: "accent"
                        font.weight: Font.Medium
                        text: root.qr.ssid || Net.ssid
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "sm"
                        tone: "muted"
                        singleLine: false
                        text: qsTr("Scan this QR code with your phone camera to join automatically.")
                    }

                    TextLabel {
                        visible: root.band(root.info.freq) !== "" || root.info.ip !== undefined
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        tabular: true
                        text: (root.band(root.info.freq) ? root.band(root.info.freq) : "")
                            + (root.band(root.info.freq) && root.info.ip ? " · " : "")
                            + (root.info.ip ? root.info.ip : "")
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Tokens.px(160)
                    Layout.preferredHeight: Tokens.px(160)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Tokens.radius.md
                    color: "#ffffff"

                    Canvas {
                        id: codeCanvas
                        anchors.fill: parent
                        anchors.margins: Tokens.space.xs
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = "#ffffff"
                            ctx.fillRect(0, 0, width, height)
                            const n = root.qr.size
                            if (n <= 0) return
                            const quiet = 4
                            const cells = n + 2 * quiet
                            const m = Math.floor(Math.min(width, height) / cells)
                            const ox = Math.floor((width - cells * m) / 2) + quiet * m
                            const oy = Math.floor((height - cells * m) / 2) + quiet * m
                            ctx.fillStyle = "#000000"
                            for (let y = 0; y < n; y++) {
                                const row = root.qr.rows[y]
                                for (let x = 0; x < n; x++) {
                                    if (row.charAt(x) === "1")
                                        ctx.fillRect(ox + x * m, oy + y * m, m, m)
                                }
                            }
                        }
                    }

                    TextLabel {
                        visible: root.qr.size === 0
                        anchors.centerIn: parent
                        width: parent.width - Tokens.space.md
                        horizontalAlignment: Text.AlignHCenter
                        singleLine: false
                        role: "caption"
                        color: "#000000"
                        text: root.qr.error !== "" ? root.qr.error : qsTr("Generating QR…")
                    }
                }
            }
        }
    }

    // ── AVAILABLE NETWORKS LIST ─────────────────────────────────────────────────
    Surface {
        visible: Net.hasWifi && Net.enabled && !root.sharing && root.availNets.length > 0
        width: parent.width
        role: "card"
        horizontalPadding: Tokens.space.sm
        verticalPadding: Tokens.space.sm
        radius: Tokens.radius.md
        implicitHeight: Math.min(Tokens.px(48) * 5, netList.contentHeight) + verticalPadding * 2

        ListView {
            id: netList

            anchors.fill: parent
            spacing: 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.availNets

            delegate: Item {
                id: netRow

                required property var modelData
                required property int index

                property bool showPw: false
                readonly property bool askingPw: root.passwordSsid !== "" && root.passwordSsid === netRow.modelData.name

                onAskingPwChanged: {
                    if (askingPw) {
                        showPw = false
                        inlinePwField.text = ""
                        Qt.callLater(() => {
                            inlinePwField.focusInput()
                            root.reveal(netRow)
                        })
                    }
                }

                width: netList.width
                implicitHeight: netRow.askingPw
                    ? (netRowCol.implicitHeight + Tokens.space.sm * 2)
                    : (netRow.modelData.known ? Tokens.px(54) : Tokens.px(48))

                Rectangle {
                    visible: netRow.index > 0
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Tokens.space.md
                    anchors.rightMargin: Tokens.space.md
                    height: Tokens.hairlineWidth
                    color: Tokens.color.hairline
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: netRow.index > 0 ? Tokens.space.xxs : 0
                    anchors.bottomMargin: Tokens.space.xxs
                    radius: Tokens.radius.sm
                    color: (rowHover.hovered || root.sel === netRow.index || netRow.askingPw)
                        ? Tokens.veilHoverOf(Tokens.surfaceStyle)
                        : "transparent"

                    Behavior on color {
                        enabled: !Tokens.reducedMotion && !Tokens.gameMode
                        ColorAnimation { duration: Tokens.motion.fast }
                    }
                }

                FocusRing {
                    active: root.sel === netRow.index
                    ringRadius: Tokens.radius.sm
                }

                ColumnLayout {
                    id: netRowCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Tokens.space.md
                    anchors.rightMargin: Tokens.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.space.sm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.md

                        WifiIcon {
                            level: netRow.modelData.signalStrength
                            size: Tokens.size.iconMd
                            color: Tokens.color.text
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.space.xxs

                            TextLabel {
                                Layout.fillWidth: true
                                role: "body"
                                text: netRow.modelData.name
                            }

                            TextLabel {
                                visible: netRow.modelData.known
                                Layout.fillWidth: true
                                role: "caption"
                                tone: "muted"
                                text: root.subtitleOf(netRow.modelData)
                            }
                        }

                        Icon {
                            visible: root.secured(netRow.modelData)
                            name: "lock"
                            size: Tokens.size.iconXs
                            tone: "muted"
                        }

                        Badge {
                            visible: netRow.modelData.known
                            text: qsTr("Saved")
                            tone: "accent"
                        }

                        TextLabel {
                            role: "sm"
                            tabular: true
                            tone: "muted"
                            text: Math.round(netRow.modelData.signalStrength * 100) + "%"
                        }

                        Button {
                            text: netRow.askingPw ? qsTr("Cancel") : qsTr("Connect")
                            variant: netRow.askingPw ? "ghost" : "secondary"
                            size: "sm"
                            accessibleLabel: netRow.askingPw
                                ? qsTr("Cancel password entry")
                                : qsTr("Connect to %1").arg(netRow.modelData.name)
                            onClicked: {
                                root.sel = netRow.index
                                root.connectNetwork(netRow.modelData)
                            }
                        }
                    }

                    // Inline password prompt inside selected network row
                    RowLayout {
                        visible: netRow.askingPw
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        TextField {
                            id: inlinePwField
                            Layout.fillWidth: true
                            icon: "lock"
                            echoMode: netRow.showPw ? TextInput.Normal : TextInput.Password
                            placeholderText: qsTr("Enter Wi-Fi password")
                            errorText: netRow.askingPw ? root.passwordError : ""
                            accessibleLabel: qsTr("Wi-Fi password for %1").arg(netRow.modelData.name)
                            onAccepted: root.submitPassword(netRow.modelData.name, inlinePwField.text)
                        }

                        Button {
                            icon: "eye"
                            variant: netRow.showPw ? "secondary" : "ghost"
                            active: netRow.showPw
                            size: "sm"
                            accessibleLabel: netRow.showPw ? qsTr("Hide password") : qsTr("Show password")
                            onClicked: netRow.showPw = !netRow.showPw
                        }

                        Button {
                            text: qsTr("Join")
                            variant: "primary"
                            size: "sm"
                            accessibleLabel: qsTr("Join %1").arg(netRow.modelData.name)
                            onClicked: root.submitPassword(netRow.modelData.name, inlinePwField.text)
                        }
                    }
                }

                HoverHandler {
                    id: rowHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.sel = netRow.index
                        root.reveal(netRow)
                    }
                }
            }
        }
    }

    // ── EMPTY STATES ────────────────────────────────────────────────────────────
    TextLabel {
        visible: Net.hasWifi && Net.enabled && Net.connected && !root.sharing && root.availNets.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        role: "caption"
        tone: "muted"
        text: root.scanning ? qsTr("Scanning for other networks…") : qsTr("No other networks nearby")
    }

    EmptyState {
        visible: !Net.hasWifi || !Net.enabled || (!root.sharing && !Net.connected && root.availNets.length === 0)
        width: parent.width
        icon: !Net.hasWifi || !Net.enabled ? "wifi-off" : "wifi"
        title: !Net.hasWifi
            ? qsTr("No Wi-Fi adapter")
            : (!Net.enabled ? qsTr("Wi-Fi is off")
                : (root.scanning ? qsTr("Discovering networks…") : qsTr("No networks found")))
        description: !Net.hasWifi
            ? qsTr("No wireless network hardware detected on this machine.")
            : (!Net.enabled ? qsTr("Turn on Wi-Fi to browse and connect to nearby networks.")
                : qsTr("Try rescanning to look for nearby access points."))
    }
}
