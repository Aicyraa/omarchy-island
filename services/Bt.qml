pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bt: Bluetooth via bluez (native Quickshell module). `hasAdapter` false means
// "no adapter": the UI hides the tile instead of showing a dead control.
Singleton {
  id: root
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool hasAdapter: adapter !== null && adapter !== undefined
  readonly property bool enabled: hasAdapter && adapter.enabled
  readonly property var devices: hasAdapter ? adapter.devices.values : []
  // Paired/known devices first, connected ones on top.
  readonly property var sorted: {
    var d = devices.slice()
    d = d.filter(function (x) { return x.paired || x.bonded || x.connected })
    d.sort(function (a, b) { return (b.connected ? 1 : 0) - (a.connected ? 1 : 0) })
    return d
  }
  readonly property var connectedDevices: devices.filter(function (d) { return d.connected })
  readonly property string connectedName: connectedDevices.length > 0
    ? (connectedDevices[0].name || connectedDevices[0].deviceName) : ""
  function setEnabled(on) { if (hasAdapter) adapter.enabled = on }
  function toggle() { if (hasAdapter) adapter.enabled = !adapter.enabled }
}
