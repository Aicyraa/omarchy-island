import QtQuick
import Quickshell.Io
import Quickshell.Networking
import ".."
import "../services"

// Wi-Fi: connection header with power and rescan buttons, four equal metric
// columns, and one uniform row per network.
// Keys: ↑/↓ select, Enter connect, D disconnect, W radio on/off, R rescan.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "↑/↓ select · Enter connect · D disconnect · W radio · R rescan · Esc close"

  property int sel: 0
  property var info: ({})
  property bool loadingInfo: true
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

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, nets.length - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (nets[sel]) connect(nets[sel]); e.accepted = true }
    else if (e.key === Qt.Key_D) { if (Net.active) Net.active.disconnect(); e.accepted = true }
    else if (e.key === Qt.Key_W) { Net.toggle(); e.accepted = true }
    else if (e.key === Qt.Key_R) { rescan(); e.accepted = true }
  }
  // Scan only while this widget is open (hygiene: no background scanning).
  Component.onCompleted: if (Net.device) Net.device.scannerEnabled = true
  Component.onDestruction: if (Net.device) Net.device.scannerEnabled = false

  // ---- header ----
  Item {
    width: parent.width; height: 44
    Rectangle { id: badge; width: 44; height: 44; radius: 22; color: Net.connected ? Theme.accent : Theme.surface
      WifiIcon { anchors.centerIn: parent; size: Theme.iconLg; off: !Net.enabled; level: Net.connected ? Net.strength : 0
        color: Net.connected ? Theme.accentText : Theme.text } }
    Column {
      anchors.left: badge.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      anchors.right: buttons.left; anchors.rightMargin: Theme.s8
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 15; font.bold: true
        text: !Net.hasWifi ? "No Wi-Fi adapter" : (!Net.enabled ? "Wi-Fi is off" : (Net.connected ? Net.ssid : "Not connected")) }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12
        text: !Net.hasWifi ? "Nothing to manage on this machine"
            : (!Net.enabled ? "Press W to turn it on" : (Net.connected ? quality(Net.strength) + " signal" : "Pick a network below")) }
    }
    Row { id: buttons; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8; visible: Net.hasWifi
      IconButton { icon: "power"; on: Net.enabled; onClicked: Net.toggle() }
      IconButton { icon: "refresh"; visible: Net.enabled; onClicked: root.rescan() } }
  }

  // ---- four equal metric columns across the full width ----
  Row {
    visible: Net.connected && !root.loadingInfo
    width: parent.width; spacing: 0
    Repeater {
      model: [ { k: "IP", v: root.info.ip || "—" },
               { k: "Signal", v: root.info.signal_dbm ? root.info.signal_dbm + " dBm" : "—" },
               { k: "Band", v: root.band(root.info.freq) || "—" },
               { k: "Speed", v: root.info.bitrate ? String(root.info.bitrate).replace(" MBit/s", " Mb/s") : "—" } ]
      delegate: Column { required property var modelData; width: parent.width / 4
        Text { textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 10 }
        Text { width: parent.width - Theme.s8; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 12; font.bold: true } }
    }
  }
  Text { visible: Net.connected && root.loadingInfo; textFormat: Text.PlainText
    text: "Reading connection details…"; color: Theme.textMuted; font.pixelSize: 11 }

  // ---- network rows (all the same height) ----
  Column {
    visible: Net.enabled && root.nets.length > 0
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
  Text { visible: Net.enabled && root.nets.length === 0; textFormat: Text.PlainText
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
