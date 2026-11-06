pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Power: battery state from UPower (native, event-driven, no polling).
Singleton {
  id: root
  readonly property var dev: UPower.displayDevice
  // No battery (desktop) -> the island hides the battery icon entirely.
  readonly property bool present: dev !== null && dev.isPresent
  // Normalise to 0..1 whichever scale the service reports.
  readonly property real level: {
    if (!present) return 0
    var p = dev.percentage
    return Math.max(0, Math.min(1, p > 1 ? p / 100 : p))
  }
  readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
  readonly property bool low: present && level <= 0.2 && !charging
}
