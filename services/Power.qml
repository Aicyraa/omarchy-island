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

  // Details for the Battery widget. UPower reports seconds and watts.
  readonly property real watts: present ? Math.abs(dev.changeRate) : 0
  readonly property real health: present ? dev.healthPercentage : 0   // 0..100
  readonly property real secondsLeft: !present ? 0 : (charging ? dev.timeToFull : dev.timeToEmpty)
  function timeText(sec) {
    if (!sec || sec <= 0) return ""
    var h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60)
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }
}
