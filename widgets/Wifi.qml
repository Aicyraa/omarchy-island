import QtQuick
import Quickshell.Io
import Quickshell.Networking
import ".."
import "../services"

// Wi-Fi: connection header with power, share and rescan buttons, four equal metric columns, and one uniform row per network.
// Share (the QR button, while connected) shows the code for joining this network, in place of the list; Esc goes back to it.
// The code comes from omarchy-network-qr, the same source the stock share card uses. The password is only inside the code.
// Keys: ↑/↓ select, Enter connect, D disconnect, W radio on/off, R rescan, Esc back from the code.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "↑/↓ select · Enter connect · D disconnect · W radio · R rescan · Q share · Esc close"
  // Esc leaves the code first, then closes the widget.
  readonly property bool capturesEscape: sharing

  property int sel: 0
  property var info: ({})
  property bool sharing: false
  property var qr: ({ rows: [], size: 0, ssid: "", error: "" })
  property bool loadingInfo: true
  // Still loading while there is no network list, or while a connected network's details have not arrived yet
  // (otherwise the shorter height would be remembered as this widget's size).
  dataLoading: (Net.enabled && Net.hasWifi && nets.length === 0) || (Net.connected && loadingInfo)
  readonly property var nets: Net.networks

  function band(f) { var n = parseFloat(f); return isNaN(n) ? "" : (n >= 5900 ? "6 GHz" : n >= 4900 ? "5 GHz" : "2.4 GHz") }
  function quality(frac) { return frac > 0.75 ? "Excellent" : frac > 0.5 ? "Good" : frac > 0.25 ? "Fair" : "Weak" }
  function secured(n) { return n.security !== WifiSecurityType.Open }
  function subtitleOf(n) { return n.connected ? "Connected" : (n.known ? "Saved" : (secured(n) ? "Secured" : "Open")) }
  function connect(n) {
    // Known networks reconnect natively. A new secured network needs a password,
    // which only NetworkManager's own prompt should ask for, so hand off to nmtui.
    if (n.connected) return
    if (n.known) n.connect()
    else Cmd.run(["omarchy-launch-floating-terminal-with-presentation", "nmtui connect"])
  }
  function rescan() { Cmd.run(["nmcli", "dev", "wifi", "rescan"]) }

  // ---- share: the QR code for the connected network ----
  function toggleShare() {
    if (sharing) { sharing = false; qrProc.running = false; return }
    if (!Net.connected) return
    qr = ({ rows: [], size: 0, ssid: Net.ssid, error: "" })
    sharing = true
    qrProc.running = true
  }
  // Parse omarchy-network-qr --meta: a "meta<TAB>iface<TAB>security<TAB>ssid" line, then one row of 0/1 per module.
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
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, nets.length - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (nets[sel]) connect(nets[sel]); e.accepted = true }
    else if (e.key === Qt.Key_D) { if (Net.active) Net.active.disconnect(); e.accepted = true }
    else if (e.key === Qt.Key_W) { Net.toggle(); e.accepted = true }
    else if (e.key === Qt.Key_R) { rescan(); e.accepted = true }
  }
  // Scan only while this widget is open (hygiene: no background scanning).
  // The menu's QR entry sets the intent before opening this widget. It is taken here on creation and on a later request.
  // It waits for a connection: right after start the network state may not be loaded yet.
  function takeIntent() {
    if (IslandState.intent !== "wifi-share" || !Net.connected) return
    IslandState.intent = ""
    if (!sharing) toggleShare()
  }
  Connections { target: IslandState; function onIntentChanged() { root.takeIntent() } }
  Connections { target: Net; function onConnectedChanged() { root.takeIntent() } }
  Component.onCompleted: {
    if (Net.device) Net.device.scannerEnabled = true
    takeIntent()
  }
  Component.onDestruction: if (Net.device) Net.device.scannerEnabled = false

  // ---- header ----
  Item {
    width: parent.width; height: 44
    Rectangle { antialiasing: true; id: badge; width: 44; height: 44; radius: 22; color: Net.connected ? Theme.accentFill : Theme.surface
      WifiIcon { anchors.centerIn: parent; size: Theme.iconLg; off: !Net.enabled; level: Net.connected ? Net.strength : 0
        color: Net.connected ? Theme.accentText : Theme.text } }
    Column {
      anchors.left: badge.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      anchors.right: buttons.left; anchors.rightMargin: Theme.s8
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
        text: !Net.hasWifi ? "No Wi-Fi adapter" : (!Net.enabled ? "Wi-Fi is off" : (Net.connected ? Net.ssid : "Not connected")) }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12
        text: !Net.hasWifi ? "Nothing to manage on this machine"
            : (!Net.enabled ? "Wi-Fi is off" : (Net.connected ? quality(Net.strength) + " signal" : "Pick a network below")) }
    }
    Row { id: buttons; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8; visible: Net.hasWifi
      IconButton { icon: "power"; on: Net.enabled; onClicked: Net.toggle() }
      IconButton { icon: "qr"; visible: Net.connected; on: root.sharing; onClicked: root.toggleShare() }
      IconButton { icon: "refresh"; visible: Net.enabled; onClicked: root.rescan() } }
  }

  // ---- four equal metric columns across the full width ----
  Row {
    visible: Net.connected && !root.loadingInfo && !root.sharing
    width: parent.width; spacing: 0
    Repeater {
      model: [ { k: "IP", v: root.info.ip || "—" },
               { k: "Signal", v: root.info.signal_dbm ? root.info.signal_dbm + " dBm" : "—" },
               { k: "Band", v: root.band(root.info.freq) || "—" },
               { k: "Speed", v: root.info.bitrate ? String(root.info.bitrate).replace(" MBit/s", " Mb/s") : "—" } ]
      delegate: Column { required property var modelData; width: parent.width / 4
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 11 }
        Text { width: parent.width - Theme.s8; anchors.horizontalCenter: parent.horizontalCenter; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
          textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel } }
    }
  }
  Text { visible: Net.connected && root.loadingInfo && !root.sharing; textFormat: Text.PlainText
    text: "Reading connection details…"; color: Theme.textMuted; font.pixelSize: 11 }

  // ---- network rows (all the same height) ----
  // The code: white (a QR code must stay dark-on-light whatever the theme is), with a quiet zone of four modules.
  Item {
    visible: root.sharing
    width: parent.width; height: 268
    Rectangle {
      id: codeCard
      anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top
      width: 220; height: 220; radius: Theme.tileRadius; color: "#ffffff"; antialiasing: true
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
      Text { visible: root.qr.size === 0; anchors.centerIn: parent; textFormat: Text.PlainText
        text: root.qr.error !== "" ? root.qr.error : "Making the code…"; color: "#444444"; font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter; width: parent.width - 24; wrapMode: Text.WordWrap }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: codeCard.bottom; anchors.topMargin: Theme.s12
      textFormat: Text.PlainText; text: "Scan with a phone to join " + root.qr.ssid; color: Theme.textMuted; font.pixelSize: 12 }
  }
  onQrChanged: codeCanvas.requestPaint()

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
  Text { visible: Net.enabled && root.nets.length === 0 && !root.sharing; textFormat: Text.PlainText
    text: "No networks found"; color: Theme.textMuted; font.pixelSize: 13 }

  // The reading is a snapshot taken when the widget opens (no polling).
  Process {
    running: Net.connected
    command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector { onStreamFinished: {
      var o = {}
      text.split("\n").forEach(function (l) { var t = l.split("\t"); if (t.length >= 2) o[t[0]] = t[1] })
      root.info = o; root.loadingInfo = false
    } }
    onExited: root.loadingInfo = false
  }
}
