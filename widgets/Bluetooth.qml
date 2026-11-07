import QtQuick
import Quickshell.Bluetooth
import ".."
import "../services"

// Bluetooth: adapter power + scan buttons, and devices grouped into Connected,
// Paired and Available (empty groups are hidden). Each row shows a type icon,
// name, status (with a visible pending state) and battery as icon + percent.
// Keys: ↑/↓ select, Enter connect/disconnect, B radio on/off, S scan.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "↑/↓ select · Enter connect/disconnect · B radio · S scan · Esc close"

  property int sel: 0
  property var pending: ({})                 // address -> true while an action is in flight

  function iconOf(d) {
    var i = String(d.icon || "")
    return i.indexOf("head") >= 0 || i.indexOf("audio") >= 0 ? "headphones" : i.indexOf("mouse") >= 0 ? "mouse"
         : i.indexOf("keyboard") >= 0 ? "keyboard" : i.indexOf("phone") >= 0 ? "phone" : i.indexOf("gaming") >= 0 ? "gamepad" : "bluetooth"
  }
  function nameOf(d) { return d.name || d.deviceName || "" }
  readonly property var all: Bt.hasAdapter ? Bt.devices.filter(function (d) { return nameOf(d) !== "" }) : []
  readonly property var connected: all.filter(function (d) { return d.connected })
  readonly property var paired: all.filter(function (d) { return !d.connected && (d.paired || d.bonded) })
  readonly property var available: all.filter(function (d) { return !d.connected && !(d.paired || d.bonded) })
  readonly property var flat: connected.concat(paired).concat(available)

  function isPending(d) { return pending[d.address] === true || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting }
  function statusOf(d) {
    if (d.state === BluetoothDeviceState.Connecting || pending[d.address] === true && !d.connected) return "Connecting…"
    if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
    return d.connected ? "Connected" : ((d.paired || d.bonded) ? "Paired" : "Available")
  }
  function toggleDevice(d) {
    var p = Object.assign({}, pending); p[d.address] = true; pending = p; settle.restart()
    if (d.connected) d.disconnect(); else d.connect()
  }
  // Pending marks clear on their own if nothing happens (so a failed connect doesn't stay stuck).
  Timer { id: settle; interval: 8000; onTriggered: root.pending = ({}) }

  // Scan: discovery runs only when asked, for 12 s, and never outlives the widget.
  function scan() { if (!Bt.enabled) return; Bt.adapter.discovering = true; scanTimer.restart() }
  Timer { id: scanTimer; interval: 12000; onTriggered: if (Bt.hasAdapter) Bt.adapter.discovering = false }
  Component.onDestruction: if (Bt.hasAdapter) Bt.adapter.discovering = false

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, flat.length - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (flat[sel]) toggleDevice(flat[sel]); e.accepted = true }
    else if (e.key === Qt.Key_B) { Bt.toggle(); e.accepted = true }
    else if (e.key === Qt.Key_S) { scan(); e.accepted = true }
  }

  // ---- header ----
  Item {
    width: parent.width; height: 44
    Rectangle { antialiasing: true; id: badge; width: 44; height: 44; radius: 22; color: Bt.enabled ? Theme.accentFill : Theme.surface
      Icon { anchors.centerIn: parent; size: Theme.iconLg; name: "bluetooth"; color: Bt.enabled ? Theme.accentText : Theme.text } }
    Column {
      anchors.left: badge.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      anchors.right: buttons.left; anchors.rightMargin: Theme.s8
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
        text: !Bt.hasAdapter ? "No Bluetooth adapter" : (!Bt.enabled ? "Bluetooth is off" : (Bt.connectedName !== "" ? Bt.connectedName : "On")) }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12
        text: !Bt.hasAdapter ? "Nothing to manage on this machine" : (!Bt.enabled ? "Bluetooth is off"
            : (root.connected.length + " connected" + (root.paired.length > 0 ? " · " + root.paired.length + " more paired" : ""))) }
    }
    Row { id: buttons; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8; visible: Bt.hasAdapter
      IconButton { icon: "power"; on: Bt.enabled; onClicked: Bt.toggle() }
      IconButton { icon: "scan"; visible: Bt.enabled; busy: Bt.hasAdapter && Bt.adapter.discovering; onClicked: root.scan() } }
  }

  // ---- groups ----
  component Group: Column {
    id: g
    property string label: ""
    property var devices: []
    property int offset: 0
    width: parent.width; spacing: Theme.rowGap
    visible: devices.length > 0
    Text { textFormat: Text.PlainText; text: g.label; color: Theme.textMuted; font.pixelSize: 11; font.weight: Theme.weightLabel }
    Repeater {
      model: g.devices
      delegate: ListRow {
        required property var modelData
        required property int index
        width: parent.width
        icon: root.iconOf(modelData); title: root.nameOf(modelData); subtitle: root.statusOf(modelData)
        trailingIcon: modelData.batteryAvailable ? "battery" : ""
        trailing: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
        active: modelData.connected; pending: root.isPending(modelData)
        selected: root.sel === g.offset + index
        onSelectedChanged: if (selected) root.reveal(this)
        onClicked: { root.sel = g.offset + index; root.toggleDevice(modelData) }
      }
    }
  }
  Group { visible: Bt.enabled && devices.length > 0; label: "Connected"; devices: root.connected; offset: 0 }
  Group { visible: Bt.enabled && devices.length > 0; label: "Paired"; devices: root.paired; offset: root.connected.length }
  Group { visible: Bt.enabled && devices.length > 0; label: "Available"; devices: root.available; offset: root.connected.length + root.paired.length }
  Text { visible: Bt.enabled && root.flat.length === 0; textFormat: Text.PlainText
    text: "No devices yet. Use the scan button."; color: Theme.textMuted; font.pixelSize: 13 }
}
