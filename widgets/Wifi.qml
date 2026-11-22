import QtQuick
import Quickshell.Io
import Quickshell.Networking
import ".."
import "../services"

// Wi-Fi: asymmetrical header + compact connection metrics, auto-scan on open (zero
// restart/refresh buttons in the header), and stable content sizing (useReserve: false)
// so post-boot opens never reserve phantom height that collapses later.
// Keys: ↑/↓ select, Enter connect, D disconnect, W radio on/off, R rescan, Q share, Esc close.
WidgetPanel {
  id: root
  preferredWidth: 500
  useReserve: false
  hint: "↑/↓ select · Enter connect · D disconnect · W radio · R rescan · Q share · Esc close"
  readonly property bool capturesEscape: sharing

  property int sel: 0
  property var info: ({})
  property bool sharing: false
  property bool scanning: false
  property var qr: ({ rows: [], size: 0, ssid: "", error: "" })
  readonly property var nets: Net.networks

  function band(f) { var n = parseFloat(f); return isNaN(n) ? "" : (n >= 5900 ? "6 GHz" : n >= 4900 ? "5 GHz" : "2.4 GHz") }
  function quality(frac) { return frac > 0.75 ? "Excellent" : frac > 0.5 ? "Good" : frac > 0.25 ? "Fair" : "Weak" }
  function secured(n) { return n.security !== WifiSecurityType.Open }
  function subtitleOf(n) { return n.connected ? "Connected" : (n.known ? "Saved" : (secured(n) ? "Secured" : "Open")) }
  function connect(n) {
    if (n.connected) return
    if (n.known) n.connect()
    else Cmd.run(["omarchy-launch-floating-terminal-with-presentation", "nmtui connect"])
  }
  function rescan() {
    if (!Net.enabled) return
    scanning = true
    Cmd.run(["nmcli", "dev", "wifi", "rescan"])
    scanDone.restart()
  }
  Timer { id: scanDone; interval: 2000; onTriggered: root.scanning = false }

  // ---- share: QR code for the connected network ----
  function toggleShare() {
    if (sharing) { sharing = false; qrProc.running = false; return }
    if (!Net.connected) return
    qr = ({ rows: [], size: 0, ssid: Net.ssid, error: "" })
    sharing = true
    qrProc.running = true
  }
  Process {
    id: qrProc
    command: ["omarchy-network-qr", "--meta"]
    stdout: StdioCollector { onStreamFinished: {
      var lines = String(text || "").trim().split(/\r?\n/).filter(function (l) { return l !== "" })
      var ssid = Net.ssid
      if (lines.length > 0 && lines[0].indexOf("meta\t") === 0) {
        var f = lines.shift().split("\t"); ssid = f.slice(3).join("\t") || ssid
      }
      var size = lines.length > 0 ? lines[0].length : 0
      var ok = size > 0 && size === lines.length
      for (var i = 0; ok && i < lines.length; i++) if (lines[i].length !== size || !/^[01]+$/.test(lines[i])) ok = false
      root.qr = ({ rows: ok ? lines : [], size: ok ? size : 0, ssid: ssid, error: ok ? "" : "Could not make the code" })
    } }
    onExited: function (code) { if (code !== 0) root.qr = ({ rows: [], size: 0, ssid: Net.ssid, error: "Could not make the code" }) }
  }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Escape && sharing) { sharing = false; qrProc.running = false; e.accepted = true; return }
    if (sharing) return
    if (e.key === Qt.Key_Q) { toggleShare(); e.accepted = true; return }
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, nets.length - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (nets[sel]) connect(nets[sel]); e.accepted = true }
    else if (e.key === Qt.Key_D) { if (Net.active) Net.active.disconnect(); e.accepted = true }
    else if (e.key === Qt.Key_W) { Net.toggle(); e.accepted = true }
    else if (e.key === Qt.Key_R) { rescan(); e.accepted = true }
  }

  function takeIntent() {
    if (IslandState.intent !== "wifi-share" || !Net.connected) return
    IslandState.intent = ""
    if (!sharing) toggleShare()
  }
  Connections { target: IslandState; function onIntentChanged() { root.takeIntent() } }
  Connections { target: Net; function onConnectedChanged() { root.takeIntent(); if (Net.connected) root.refreshInfo() } }
  Timer { id: initialScan; interval: 150; running: true; onTriggered: root.rescan() }
  Component.onCompleted: {
    if (Net.device) Net.device.scannerEnabled = true
    takeIntent()
  }
  Component.onDestruction: if (Net.device) Net.device.scannerEnabled = false

  // ---- header (Power + QR only; both circular restart/refresh buttons removed) ----
  Item {
    width: parent.width; height: 44
    SmoothRect {
      id: badge; width: 44; height: 44; radius: 22
      color: Net.connected ? Theme.accentFill : Theme.surface
      WifiIcon {
        anchors.centerIn: parent; size: Theme.iconLg; off: !Net.enabled; level: Net.connected ? Net.strength : 0
        color: Net.connected ? Theme.accentText : Theme.text
      }
    }
    Column {
      anchors.left: badge.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      anchors.right: buttons.left; anchors.rightMargin: Theme.s8; spacing: 1
      Label {
        width: parent.width; elide: Text.ElideRight
        color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
        text: !Net.hasWifi ? "No Wi-Fi adapter" : (!Net.enabled ? "Wi-Fi is off" : (Net.connected ? Net.ssid : "Not connected"))
      }
      Label {
        width: parent.width; elide: Text.ElideRight
        color: Theme.textMuted; font.pixelSize: Theme.typeBody
        text: !Net.hasWifi ? "Nothing to manage on this machine"
            : (!Net.enabled ? "Turn on to browse networks"
              : (Net.connected ? (quality(Net.strength) + " · " + Math.round(Net.strength * 100) + "%")
                : (root.scanning ? "Scanning for networks…" : "Pick a network below")))
      }
    }
    Row {
      id: buttons; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8; visible: Net.hasWifi
      IconButton { icon: "qr"; visible: Net.connected; on: root.sharing; onClicked: root.toggleShare() }
      IconButton { icon: "power"; on: Net.enabled; onClicked: Net.toggle() }
    }
  }

  // ---- asymmetrical metrics strip: IP (wide) + Signal / Band / Speed (compact chips); constant height, never flickers ----
  Row {
    visible: Net.connected && !root.sharing
    width: parent.width; spacing: Theme.s8
    readonly property real ipW: Math.round((width - 3 * Theme.s8) * 0.34)
    readonly property real metricW: (width - 3 * Theme.s8 - ipW) / 3
    Repeater {
      model: [
        { k: "IP Address", v: root.info.ip || "—", w: parent.ipW },
        { k: "Signal", v: root.info.signal_dbm ? root.info.signal_dbm + " dBm" : "—", w: parent.metricW },
        { k: "Band", v: root.band(root.info.freq) || "—", w: parent.metricW },
        { k: "Link", v: root.info.bitrate ? String(root.info.bitrate).replace(" MBit/s", " Mb/s") : "—", w: parent.metricW }
      ]
      delegate: SmoothRect {
        required property var modelData
        width: modelData.w; height: 46; radius: Theme.radiusChip + 2; color: Theme.surface
        Column {
          anchors.centerIn: parent; width: parent.width - Theme.s12; spacing: 2
          Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: modelData.k; color: Theme.textMuted; font.pixelSize: Theme.typeCaption
          }
          Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; mono: true
            text: modelData.v; color: Theme.text; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
          }
        }
      }
    }
  }

  // ---- QR code share view ----
  Item {
    visible: root.sharing
    width: parent.width; height: 268
    SmoothRect {
      id: codeCard
      anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top
      width: 220; height: 220; radius: Theme.tileRadius; color: "#ffffff"
      Canvas {
        id: codeCanvas
        anchors.fill: parent; anchors.margins: 10
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.fillStyle = "#ffffff"; ctx.fillRect(0, 0, width, height)
          var n = root.qr.size
          if (n <= 0) return
          var quiet = 4, cells = n + 2 * quiet
          var m = Math.floor(Math.min(width, height) / cells)
          var ox = Math.floor((width - cells * m) / 2) + quiet * m, oy = Math.floor((height - cells * m) / 2) + quiet * m
          ctx.fillStyle = "#000000"
          for (var y = 0; y < n; y++) {
            var row = root.qr.rows[y]
            for (var x = 0; x < n; x++) if (row.charAt(x) === "1") ctx.fillRect(ox + x * m, oy + y * m, m, m)
          }
        }
      }
      Label {
        visible: root.qr.size === 0; anchors.centerIn: parent
        text: root.qr.error !== "" ? root.qr.error : "Making the code…"; color: "#444444"; font.pixelSize: Theme.typeBody
        horizontalAlignment: Text.AlignHCenter; width: parent.width - 24; wrapMode: Text.WordWrap
      }
    }
    Label {
      anchors.horizontalCenter: parent.horizontalCenter; anchors.top: codeCard.bottom; anchors.topMargin: Theme.s12
      text: "Scan with a phone to join " + root.qr.ssid; color: Theme.textMuted; font.pixelSize: Theme.typeBody
    }
  }
  onQrChanged: codeCanvas.requestPaint()

  // ---- available networks ----
  Column {
    visible: Net.enabled && root.nets.length > 0 && !root.sharing
    width: parent.width; spacing: Theme.rowGap
    Repeater {
      model: root.nets
      delegate: ListRow {
        required property var modelData
        required property int index
        width: parent.width
        title: modelData.name; subtitle: root.subtitleOf(modelData)
        trailing: Math.round(modelData.signalStrength * 100) + "%"
        trailingIcon: root.secured(modelData) ? "lock-small" : ""
        active: modelData.connected
        selected: root.sel === index
        leading: Component { WifiIcon { level: modelData.signalStrength; size: Theme.iconMd; color: modelData.connected ? Theme.accentInk : Theme.text } }
        onSelectedChanged: if (selected) root.reveal(this)
        onClicked: { root.sel = index; root.connect(modelData) }
      }
    }
  }
  Label {
    visible: Net.enabled && root.nets.length === 0 && !root.sharing
    text: root.scanning ? "Discovering networks…" : "No networks found"; color: Theme.textMuted; font.pixelSize: Theme.typeBody
  }

  // Silent background refresh of connection details while open (never clears already-loaded metrics).
  function refreshInfo() { if (Net.connected && !infoProc.running) infoProc.running = true }
  Timer { interval: 5000; repeat: true; running: Net.connected; onTriggered: root.refreshInfo() }
  Process {
    id: infoProc
    running: Net.connected
    command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector { onStreamFinished: {
      var o = {}
      text.split("\n").forEach(function (l) { var t = l.split("\t"); if (t.length >= 2) o[t[0]] = t[1] })
      root.info = o
    } }
  }
}
