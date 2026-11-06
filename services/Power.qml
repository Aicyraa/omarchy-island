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
  readonly property bool full: present && dev.state === UPowerDeviceState.FullyCharged
  readonly property bool discharging: present && dev.state === UPowerDeviceState.Discharging
  readonly property string stateText: !present ? "" : full ? "Fully charged" : charging ? "Charging"
    : discharging ? "Discharging" : (dev.state === UPowerDeviceState.PendingCharge ? "Not charging" : "")
  readonly property real watts: present ? Math.abs(dev.changeRate) : 0
  // Health = energyFull / energyFullDesign. UPower exposes it as healthPercentage when it
  // knows it, and as energyCapacity (the same ratio) otherwise.
  // (Quickshell does not expose the design capacity, so when healthPercentage is unavailable the
  // Battery widget reads it once from `upower -i`.)
  readonly property real health: !present ? 0 : (dev.healthSupported && dev.healthPercentage > 0 ? dev.healthPercentage : 0)
  readonly property real secondsLeft: !present ? 0 : (charging ? dev.timeToFull : (discharging ? dev.timeToEmpty : 0))
  function timeText(sec) {
    if (!sec || sec <= 0) return ""
    var h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60)
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }
}
