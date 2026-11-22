import QtQuick
import Quickshell.Bluetooth
import ".."
import "../services"

// Bluetooth: asymmetrical hero header with live connected-device details (type icon, name,
// status, MAC, disconnect action, and offset battery card), auto-discovery on open so all
// available devices render immediately, zero restart buttons, and hover disconnect on rows.
// Keys: ↑/↓ select, Enter connect/disconnect, B radio on/off, S scan.
WidgetPanel {
  id: root
  preferredWidth: 520
  hint: "↑/↓ select · Enter connect/disconnect · B radio · S scan · Esc close"

  property int sel: 0
  property var pending: ({})

  function iconOf(d) {
    var i = String(d.icon || "")
    return i.indexOf("head") >= 0 || i.indexOf("audio") >= 0 ? "headphones" : i.indexOf("mouse") >= 0 ? "mouse"
         : i.indexOf("keyboard") >= 0 ? "keyboard" : i.indexOf("phone") >= 0 ? "phone" : i.indexOf("gaming") >= 0 ? "gamepad" : "bluetooth"
  }
  function typeLabelOf(d) {
    var i = String(d.icon || "")
    return i.indexOf("head") >= 0 || i.indexOf("audio") >= 0 ? "Audio device"
         : i.indexOf("mouse") >= 0 ? "Mouse"
         : i.indexOf("keyboard") >= 0 ? "Keyboard"
         : i.indexOf("phone") >= 0 ? "Phone"
         : i.indexOf("gaming") >= 0 ? "Controller" : "Bluetooth device"
  }
  function nameOf(d) { return d.name || d.deviceName || "" }
  readonly property var all: Bt.hasAdapter ? Bt.devices.filter(function (d) { return nameOf(d) !== "" }) : []
  readonly property var connected: all.filter(function (d) { return d.connected })
  readonly property var paired: all.filter(function (d) { return !d.connected && (d.paired || d.bonded) })
  readonly property var available: all.filter(function (d) { return !d.connected && !(d.paired || d.bonded) })
  readonly property var flat: connected.concat(paired).concat(available)
  readonly property var primaryDevice: connected.length > 0 ? connected[0] : null
  readonly property bool discovering: Bt.hasAdapter && Bt.adapter.discovering
  useReserve: false

  function isPending(d) { return pending[d.address] === true || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting }
  function statusOf(d) {
    if (d.state === BluetoothDeviceState.Connecting || (pending[d.address] === true && !d.connected)) return "Connecting…"
    if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
    return d.connected ? "Connected" : ((d.paired || d.bonded) ? "Paired" : "Available")
  }
  function toggleDevice(d) {
    var p = Object.assign({}, pending); p[d.address] = true; pending = p; settle.restart()
    if (d.connected) d.disconnect(); else d.connect()
  }
  Timer { id: settle; interval: 8000; onTriggered: root.pending = ({}) }

  // Auto-discover immediately when opened so nearby available devices populate right away.
  function scan() { if (!Bt.enabled) return; Bt.adapter.discovering = true; scanTimer.restart() }
  Timer { id: scanTimer; interval: 15000; onTriggered: if (Bt.hasAdapter) Bt.adapter.discovering = false }
  Component.onCompleted: scan()
  Component.onDestruction: if (Bt.hasAdapter) Bt.adapter.discovering = false

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, flat.length - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (flat[sel]) toggleDevice(flat[sel]); e.accepted = true }
    else if (e.key === Qt.Key_B) { Bt.toggle(); e.accepted = true }
    else if (e.key === Qt.Key_S) { scan(); e.accepted = true }
  }

  // ---- top header: asymmetrical connected-device hero when connected, clean status bar otherwise ----
  Item {
    width: parent.width
    height: (Bt.enabled && root.primaryDevice) ? heroRow.implicitHeight : 44

    // Compact header when adapter is off, missing, or nothing is connected.
    Item {
      visible: !(Bt.enabled && root.primaryDevice)
      width: parent.width; height: 44
      SmoothRect {
        id: badge; width: 44; height: 44; radius: 22
        color: Bt.enabled ? Theme.accentFill : Theme.surface
        Icon { anchors.centerIn: parent; size: Theme.iconLg; name: "bluetooth"; color: Bt.enabled ? Theme.accentText : Theme.text }
      }
      Column {
        anchors.left: badge.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
        anchors.right: offBtns.left; anchors.rightMargin: Theme.s8; spacing: 1
        Label {
          width: parent.width; elide: Text.ElideRight
          color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
          text: !Bt.hasAdapter ? "No Bluetooth adapter" : (!Bt.enabled ? "Bluetooth is off" : "Bluetooth")
        }
        Label {
          width: parent.width; elide: Text.ElideRight
          color: Theme.textMuted; font.pixelSize: Theme.typeBody
          text: !Bt.hasAdapter ? "Nothing to manage on this machine"
              : (!Bt.enabled ? "Turn on to connect devices"
                : (root.discovering ? "Scanning for nearby devices…" : (root.paired.length + " paired · " + root.available.length + " nearby")))
        }
      }
      Row {
        id: offBtns; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
        visible: Bt.hasAdapter
        IconButton { icon: "power"; on: Bt.enabled; onClicked: Bt.toggle() }
      }
    }

    // Asymmetrical hero section for connected device details (Item 3.1).
    Row {
      id: heroRow
      visible: Bt.enabled && root.primaryDevice !== null
      width: parent.width; spacing: Theme.s12
      readonly property real leftW: Math.round((width - Theme.s12) * 0.62)
      readonly property real rightW: width - Theme.s12 - leftW

      // Dominant left card: connected device identity, class, MAC, and quick disconnect.
      SmoothRect {
        width: heroRow.leftW; height: 92; radius: Theme.tileRadius; color: Theme.surface
        SmoothRect {
          id: devDisc; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter
          width: 48; height: 48; radius: 24; color: Theme.accentFill
          Icon { anchors.centerIn: parent; name: root.primaryDevice ? root.iconOf(root.primaryDevice) : "bluetooth"; size: Theme.iconLg; color: Theme.accentText }
        }
        Column {
          anchors.left: devDisc.right; anchors.leftMargin: Theme.s12
          anchors.right: parent.right; anchors.rightMargin: Theme.s12
          anchors.verticalCenter: parent.verticalCenter; spacing: 3
            Row {
              width: parent.width; spacing: 6
              SmoothRect {
                width: 7; height: 7; radius: 3.5; color: Theme.successInk; anchors.verticalCenter: parent.verticalCenter
              }
              Label {
                text: root.connected.length > 1 ? ("Connected · +" + (root.connected.length - 1) + " more") : "Connected"
                color: Theme.successInk; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
              }
            }
            Label {
              width: parent.width; elide: Text.ElideRight
              text: root.primaryDevice ? root.nameOf(root.primaryDevice) : ""
              color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
            }
            Label {
              width: parent.width; elide: Text.ElideRight; mono: true
              text: root.primaryDevice
                ? (root.typeLabelOf(root.primaryDevice) + (root.primaryDevice.address ? " · " + root.primaryDevice.address : ""))
                : ""
              color: Theme.textMuted; font.pixelSize: Theme.typeCaption
            }
          }
        }

        // Offset right column: battery detail (or link summary) + adapter power control.
        Column {
          width: heroRow.rightW; spacing: Theme.s8
          SmoothRect {
            width: parent.width; height: 48; radius: Theme.tileRadius; color: Theme.surfaceRaised
            readonly property bool hasBat: root.primaryDevice !== null && root.primaryDevice.batteryAvailable
            readonly property int batPct: hasBat ? Math.round(root.primaryDevice.battery * 100) : 0
            Row {
              anchors.left: parent.left; anchors.leftMargin: Theme.s12; anchors.right: parent.right; anchors.rightMargin: Theme.s12
              anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
              Icon {
                name: parent.parent.hasBat ? "battery" : "bluetooth"; size: Theme.iconMd
                color: parent.parent.hasBat && parent.parent.batPct <= 20 ? Theme.dangerInk : Theme.accentInk
                anchors.verticalCenter: parent.verticalCenter
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 1
                Label {
                  mono: true
                  text: parent.parent.parent.hasBat ? (parent.parent.parent.batPct + "%") : (root.connected.length + " active")
                  color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong
                }
                Label {
                  text: parent.parent.parent.hasBat ? "Battery" : (root.discovering ? "Scanning…" : (root.paired.length + " paired"))
                  color: Theme.textMuted; font.pixelSize: Theme.typeCaption
                }
              }
            }
          }
          Row {
            width: parent.width; height: 36; spacing: Theme.s8
            SmoothRect {
              width: parent.width - 36 - Theme.s8; height: 36; radius: 18
              color: discArea.pressed ? Theme.danger : (discArea.containsMouse ? Theme.mix(Theme.surface, Theme.danger, 0.25) : Theme.surface)
              Behavior on color { ColorAnimation { duration: 130 } }
              Row {
                anchors.centerIn: parent; spacing: 6
                Icon { name: "unlink"; size: Theme.iconSm - 1; color: discArea.pressed ? Theme.textOnDanger : (discArea.containsMouse ? Theme.dangerInk : Theme.text); anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Disconnect"; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
                  color: discArea.pressed ? Theme.textOnDanger : (discArea.containsMouse ? Theme.dangerInk : Theme.text); anchors.verticalCenter: parent.verticalCenter }
              }
            MouseArea {
              id: discArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: if (root.primaryDevice) root.toggleDevice(root.primaryDevice)
            }
          }
          IconButton { icon: "power"; on: Bt.enabled; onClicked: Bt.toggle() }
        }
      }
    }
  }

  // ---- device groups ----
  component Group: Column {
    id: g
    property string label: ""
    property string badge: ""
    property var devices: []
    property int offset: 0
    width: parent.width; spacing: Theme.rowGap
    visible: devices.length > 0
    Item {
      width: parent.width; height: 18
      Label {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        text: g.label; color: Theme.textMuted
        font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
      }
      Label {
        visible: g.badge !== ""
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: g.badge; color: Theme.accentInk
        font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
      }
    }
    Repeater {
      model: g.devices
      delegate: ListRow {
        required property var modelData
        required property int index
        width: parent.width
        icon: root.iconOf(modelData); title: root.nameOf(modelData); subtitle: root.statusOf(modelData)
        trailingIcon: modelData.batteryAvailable ? "battery" : ""
        trailing: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
        hoverActionIcon: modelData.connected ? "unlink" : ""
        active: modelData.connected; pending: root.isPending(modelData)
        selected: root.sel === g.offset + index
        onSelectedChanged: if (selected) root.reveal(this)
        onClicked: { root.sel = g.offset + index; root.toggleDevice(modelData) }
        onHoverActionClicked: if (modelData.connected) root.toggleDevice(modelData)
      }
    }
  }

  Group { visible: Bt.enabled && devices.length > 0; label: "Connected"; devices: root.connected; offset: 0 }
  Group { visible: Bt.enabled && devices.length > 0; label: "Paired"; devices: root.paired; offset: root.connected.length }
  Group {
    visible: Bt.enabled && devices.length > 0
    label: "Available"
    badge: root.discovering ? "Scanning…" : ""
    devices: root.available
    offset: root.connected.length + root.paired.length
  }
  Label {
    visible: Bt.enabled && root.flat.length === 0
    text: root.discovering ? "Scanning for nearby Bluetooth devices…" : "No devices found (press S to scan)"
    color: Theme.textMuted; font.pixelSize: Theme.typeBody
  }
}
