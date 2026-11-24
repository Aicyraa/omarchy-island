pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "qml/Core"
import "qml/Services"
import "qml/QuickshellDS/Theme"

// Bar: thin Qt 6 bootstrap for Omarchy Island.
Item {
  id: root

  property var barConfig: ({})
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property string omarchyPath: ""
  property bool rig: false

  readonly property bool barHidden: IslandState.barHidden
  readonly property int barSize: 42
  readonly property string position: ConfigStore.barPosition
  readonly property string fontFamily: ""
  readonly property var screenBarSizes: ({})

  Variants {
    model: Quickshell.screens
    delegate: ClickCatcher {}
  }
  Variants {
    model: Quickshell.screens
    delegate: IslandWindow { rig: root.rig }
  }

  Loader { source: root.rig ? "qml/Ipc/PlainIpc.qml" : "qml/Ipc/HostIpc.qml" }
  Loader { active: !root.rig; source: "qml/Ipc/HostIndicatorsIpc.qml" }
  Loader { active: !root.rig; source: "qml/Ipc/HostBarIpc.qml" }

  Component.onCompleted: {
    // Instantiate OmarchyAdapter and ConfigStore singletons immediately
    var _adapter = OmarchyAdapter.enabled
    var _cfg = ConfigStore.surfaceStyle
    Prefetch.start()
    Cmd.dryRun = rig
    Indicators.refresh()
    Indicators.checkUpdates()
    Brightness.refresh()
    IslandState.syncHidden()
  }

  Variants {
    model: ["settings", "home", "media", "capture", "wifi", "bluetooth", "audio", "display",
            "battery", "calendar", "worldclock", "power", "notifications", "system", "tray",
            "theme", "look", "weather", "agent"]
    GlobalShortcut {
      required property string modelData
      appid: "island"
      name: modelData
      description: "Toggle the island " + modelData + " widget"
      onPressed: IslandState.toggleWidget(modelData, "", true)
    }
  }

  property bool armed: false
  Timer { interval: 2000; running: true; onTriggered: root.armed = true }
  Connections {
    target: Power
    function onChargingChanged() {
      if (root.armed && Power.present)
        IslandState.showHud("charger", Power.level * 100, Power.charging ? "Charging" : "On battery", 0)
    }
  }
}
