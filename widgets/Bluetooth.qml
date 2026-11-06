import QtQuick
import ".."
import "../services"

// Bluetooth: radio switch and the list of known devices with battery level.
// Keys: ↑/↓ select, Enter connect/disconnect, B radio on/off.
Item {
  id: root
  focus: true
  property string hint: "↑/↓ select · Enter connect/disconnect · B radio · Esc close"
  property int sel: 0
  readonly property var devs: Bt.sorted

  function toggleDevice(d) { if (d.connected) d.disconnect(); else d.connect() }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, devs.length - 1); list.positionViewAtIndex(sel, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); list.positionViewAtIndex(sel, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (devs[sel]) toggleDevice(devs[sel]); e.accepted = true }
    else if (e.key === Qt.Key_B) { Bt.toggle(); e.accepted = true }
  }

  Rectangle { x: 18; y: 16; width: 44; height: 44; radius: 22; color: Bt.enabled ? Theme.accent : Theme.surface
    Icon { anchors.centerIn: parent; size: 22; name: "bluetooth"; color: Bt.enabled ? Theme.accentText : Theme.text } }
  Column {
    x: 74; y: 18; spacing: 2
    Text { textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 15; font.bold: true
      text: !Bt.hasAdapter ? "No Bluetooth adapter" : (!Bt.enabled ? "Bluetooth is off" : (Bt.connectedName !== "" ? Bt.connectedName : "On")) }
    Text { textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12
      text: !Bt.hasAdapter ? "Nothing to manage on this machine" : (!Bt.enabled ? "Press B to turn it on"
          : (Bt.connectedDevices.length + " connected · " + root.devs.length + " known")) }
  }

  ListView {
    id: list
    x: 10; y: 76; width: root.width - 20; height: root.height - 76 - 10
    clip: true; spacing: 2
    visible: Bt.enabled
    model: root.devs
    delegate: ListItem {
      required property var modelData
      required property int index
      width: list.width
      icon: modelData.icon && modelData.icon.indexOf("head") >= 0 ? "headphones" : "bluetooth"
      title: modelData.name || modelData.deviceName
      subtitle: modelData.connected ? "Connected" : "Paired"
      trailing: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
      active: modelData.connected
      selected: root.sel === index
      onClicked: { root.sel = index; root.toggleDevice(modelData) }
    }
  }
  Text { visible: Bt.enabled && root.devs.length === 0; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "No paired devices"; color: Theme.textMuted; font.pixelSize: 13 }
}
