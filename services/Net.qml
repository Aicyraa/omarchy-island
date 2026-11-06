pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Net: Wi-Fi state from Quickshell's native Networking module (NetworkManager
// backend here), so there is no nmcli polling. Everything is derived by
// bindings: when a device or network property changes, these re-evaluate.
Singleton {
  id: root

  // The first wifi device, or null when the machine has none ("no adapter").
  readonly property var device: {
    var devs = Networking.devices ? Networking.devices.values : []
    for (var i = 0; i < devs.length; i++)
      if (devs[i].type === DeviceType.Wifi) return devs[i]
    return null
  }
  readonly property bool hasWifi: device !== null

  // The connected network, if any.
  readonly property var active: {
    if (!device || !device.networks) return null
    var nets = device.networks.values
    for (var i = 0; i < nets.length; i++) if (nets[i].connected) return nets[i]
    return null
  }
  readonly property bool connected: active !== null
  readonly property string ssid: active ? active.name : ""
  // 0..1. Quickshell reports signalStrength as a fraction; clamp defensively.
  readonly property real strength: active ? Math.max(0, Math.min(1, active.signalStrength)) : 0

  // Radio on/off (rfkill-level, handled by NetworkManager).
  readonly property bool enabled: Networking.wifiEnabled
  function setEnabled(on) { Networking.wifiEnabled = on }
  function toggle() { Networking.wifiEnabled = !Networking.wifiEnabled }

  // Visible networks, strongest first, connected on top.
  readonly property var networks: {
    if (!device || !device.networks) return []
    var n = device.networks.values.slice()
    n.sort(function (a, b) { return (b.connected ? 2 : 0) + b.signalStrength - ((a.connected ? 2 : 0) + a.signalStrength) })
    return n
  }
}
