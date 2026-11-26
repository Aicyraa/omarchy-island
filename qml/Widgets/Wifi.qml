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

    preferredWidth: 500
    useReserve: false
    scrollTarget: (!root.sharing && Net.hasWifi && Net.enabled && root.nets.length > 0) ? netList : null
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
        if (!n) return ""
        return n.connected ? qsTr("Connected")
            : (n.known ? qsTr("Saved") : (secured(n) ? qsTr("Secured") : qsTr("Open")))
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
            passwordField.text = ""
            if (passwordSsid !== "")
                passwordTimer.restart()
        }
    }

    function submitPassword(ssid: string, pw: string): void {
        if (!pw || pw.length === 0) {
            passwordError = qsTr("Password required")
            return
        }
        passwordError = ""
        Cmd.run(["nmcli", "device", "wifi", "connect", ssid, "password", pw])
        passwordSsid = ""
        passwordField.text = ""
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
        id: passwordTimer
        interval: 40
        onTriggered: passwordField.focusInput()
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
            event.accepted = true
            return
        }
        if (root.sharing || root.passwordSsid !== "") return

        if (event.key === Qt.Key_Q) {
            root.toggleShare()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            root.sel = Math.min(root.sel + 1, Math.max(0, root.nets.length - 1))
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.sel = Math.max(root.sel - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.nets[root.sel])
                root.connectNetwork(root.nets[root.sel])
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

        Icon {
            icon: Net.enabled ? "wifi" : "wifi-off"
            size: Tokens.size.iconXl
            tone: Net.connected ? "accent" : "muted"
            framed: true
        }

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Wi-Fi")
            detail: !Net.hasWifi
                ? qsTr("No Wi-Fi adapter")
                : (!Net.enabled ? qsTr("Radio is off")
                    : (Net.connected ? Net.ssid : (root.scanning ? qsTr("Scanning…") : qsTr("Select a network"))))
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.sm

                        TextLabel {
                            role: "caption"
                            tone: "muted"
                            tabular: true
                            text: root.quality(Net.strength)
                                + (root.info.ip ? " · " + root.info.ip : "")
                                + (root.band(root.info.freq) ? " · " + root.band(root.info.freq) : "")
                                + (root.info.bitrate ? " · " + String(root.info.bitrate).replace(" MBit/s", " Mb/s") : "")
                        }
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

            // Inline QR share view
            ColumnLayout {
                visible: root.sharing
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: Tokens.px(200)
                    height: Tokens.px(200)
                    radius: Tokens.radius.md
                    color: "#ffffff"

                    Canvas {
                        id: codeCanvas
                        anchors.fill: parent
                        anchors.margins: Tokens.space.sm
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
                        width: parent.width - Tokens.space.lg
                        horizontalAlignment: Text.AlignHCenter
                        singleLine: false
                        color: "#000000"
                        text: root.qr.error !== "" ? root.qr.error : qsTr("Generating QR code…")
                    }
                }

                TextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    role: "caption"
                    tone: "muted"
                    text: qsTr("Scan with a phone to join %1").arg(root.qr.ssid)
                }
            }
        }
    }

    // ── INLINE PASSWORD PROMPT ──────────────────────────────────────────────────
    Card {
        visible: Net.hasWifi && Net.enabled && !root.sharing && root.passwordSsid !== ""
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: pwCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: pwCol
            width: parent.width
            spacing: Tokens.space.sm

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                TextLabel {
                    Layout.fillWidth: true
                    role: "sm"
                    font.weight: Font.Medium
                    text: qsTr("Connect to %1").arg(root.passwordSsid)
                }

                Button {
                    icon: "close"
                    variant: "ghost"
                    size: "sm"
                    accessibleLabel: qsTr("Cancel password entry")
                    onClicked: {
                        root.passwordSsid = ""
                        root.passwordError = ""
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    icon: "lock"
                    placeholderText: qsTr("Enter Wi-Fi password")
                    errorText: root.passwordError
                    accessibleLabel: qsTr("Wi-Fi password")
                    onAccepted: root.submitPassword(root.passwordSsid, passwordField.text)
                }

                Button {
                    text: qsTr("Join")
                    variant: "primary"
                    size: "md"
                    onClicked: root.submitPassword(root.passwordSsid, passwordField.text)
                }
            }
        }
    }

    // ── AVAILABLE NETWORKS LIST ─────────────────────────────────────────────────
    ListView {
        id: netList

        visible: Net.hasWifi && Net.enabled && !root.sharing && root.nets.length > 0
        width: parent.width
        height: Math.min(contentHeight, Tokens.px(250))
        spacing: Tokens.space.xs
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.nets

        delegate: Card {
            id: netRow

            required property var modelData
            required property int index

            width: netList.width
            horizontalPadding: Tokens.space.lg
            verticalPadding: Tokens.space.md
            hovered: rowHover.hovered || root.sel === netRow.index
            implicitHeight: netRowLayout.implicitHeight + verticalPadding * 2

            FocusRing {
                active: root.sel === netRow.index
                ringRadius: netRow.radius
            }

            RowLayout {
                id: netRowLayout
                width: parent.width
                spacing: Tokens.space.md

                WifiIcon {
                    level: netRow.modelData.signalStrength
                    size: Tokens.size.iconMd
                    color: netRow.modelData.connected ? Tokens.color.accent : Tokens.color.text
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xxs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "body"
                        font.weight: netRow.modelData.connected ? Font.Medium : Font.Normal
                        tone: netRow.modelData.connected ? "accent" : "primary"
                        text: netRow.modelData.name
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        text: root.subtitleOf(netRow.modelData)
                    }
                }

                Badge {
                    visible: root.secured(netRow.modelData)
                    text: qsTr("Secured")
                    tone: netRow.modelData.known ? "accent" : "neutral"
                }

                TextLabel {
                    role: "sm"
                    tabular: true
                    tone: "muted"
                    text: Math.round(netRow.modelData.signalStrength * 100) + "%"
                }

                Button {
                    text: netRow.modelData.connected ? qsTr("Active") : qsTr("Connect")
                    variant: netRow.modelData.connected ? "primary" : "secondary"
                    size: "sm"
                    enabled: !netRow.modelData.connected
                    accessibleLabel: qsTr("Connect to %1").arg(netRow.modelData.name)
                    onClicked: {
                        root.sel = netRow.index
                        root.connectNetwork(netRow.modelData)
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

    // ── EMPTY STATES ────────────────────────────────────────────────────────────
    EmptyState {
        visible: !Net.hasWifi || !Net.enabled || (!root.sharing && root.nets.length === 0)
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
