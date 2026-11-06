import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Wi-Fi: current connection details plus the list of networks.
// Keys: ↑/↓ select, Enter connect, D disconnect, W radio on/off.
Item {
  id: root
  focus: true
  property string hint: "↑/↓ select · Enter connect · D disconnect · W radio · Esc close"
  property int sel: 0
  property var info: ({})            // key -> value from omarchy-network-status
  property bool loadingInfo: true

  readonly property var nets: Net.networks
  function band(f) { var n = parseFloat(f); return isNaN(n) ? "" : (n >= 5900 ? "6 GHz" : n >= 4900 ? "5 GHz" : "2.4 GHz") }
  function bars(frac) { return frac > 0.75 ? "Excellent" : frac > 0.5 ? "Good" : frac > 0.25 ? "Fair" : "Weak" }

  function connect(n) {
    // Known networks reconnect natively. A new secured network needs a password,
    // which only NetworkManager's own prompt should ask for, so hand off to nmtui.
    if (n.connected) return
    if (n.known) n.connect()
    else Cmd.run(["omarchy-launch-floating-terminal-with-presentation", "nmtui connect"])
  }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, nets.length - 1); list.positionViewAtIndex(sel, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); list.positionViewAtIndex(sel, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (nets[sel]) connect(nets[sel]); e.accepted = true }
    else if (e.key === Qt.Key_D) { if (Net.active) Net.active.disconnect(); e.accepted = true }
    else if (e.key === Qt.Key_W) { Net.toggle(); e.accepted = true }
  }

  // ---- header ----
  Rectangle { x: 18; y: 16; width: 44; height: 44; radius: 22; color: Net.connected ? Theme.accent : Theme.surface
    Icon { anchors.centerIn: parent; size: 22; name: Net.enabled ? "wifi" : "wifi-off"
      color: Net.connected ? Theme.accentText : Theme.text } }
  Column {
    x: 74; y: 18; spacing: 2
    Text { textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 15; font.bold: true
      text: !Net.hasWifi ? "No Wi-Fi adapter" : (!Net.enabled ? "Wi-Fi is off" : (Net.connected ? Net.ssid : "Not connected")) }
    Text { textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12
      text: !Net.hasWifi ? "Nothing to manage on this machine"
          : (!Net.enabled ? "Press W to turn it on" : (Net.connected ? bars(Net.strength) + " signal" : "Pick a network below")) }
  }

  // ---- live details (only while connected) ----
  Grid {
    visible: Net.connected && !root.loadingInfo
    x: 18; y: 70; columns: 4; columnSpacing: 22; rowSpacing: 2
    Repeater {
      model: [
        { k: "IP", v: root.info.ip || "-" },
        { k: "Signal", v: root.info.signal_dbm ? root.info.signal_dbm + " dBm" : "-" },
        { k: "Band", v: root.band(root.info.freq) || "-" },
        { k: "Speed", v: root.info.bitrate ? String(root.info.bitrate).replace(" MBit/s", " Mb/s") : "-" }
      ]
      delegate: Column {
        required property var modelData
        Text { textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 10 }
        Text { textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 12; font.bold: true }
      }
    }
  }
  Text { visible: Net.connected && root.loadingInfo; x: 18; y: 74; textFormat: Text.PlainText
    text: "Reading connection details…"; color: Theme.textMuted; font.pixelSize: 11 }

  // ---- network list ----
  ListView {
    id: list
    x: 10; y: 122; width: root.width - 20; height: root.height - 122 - 10
    clip: true; spacing: 2
    model: root.nets
    visible: Net.enabled
    delegate: ListItem {
      required property var modelData
      required property int index
      width: list.width
      icon: "wifi"; title: modelData.name
      subtitle: modelData.connected ? "Connected" : (modelData.known ? "Saved" : "")
      trailing: Math.round(modelData.signalStrength * 100) + "%"
      active: modelData.connected
      selected: root.sel === index
      onClicked: { root.sel = index; root.connect(modelData) }
    }
  }
  Text { visible: Net.enabled && root.nets.length === 0; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "No networks found"; color: Theme.textMuted; font.pixelSize: 13 }

  // Scan for networks only while this widget is open (hygiene: no background scanning).
  Component.onCompleted: if (Net.device) Net.device.scannerEnabled = true
  Component.onDestruction: if (Net.device) Net.device.scannerEnabled = false

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
