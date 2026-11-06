import QtQuick
import Quickshell
import Quickshell.Hyprland
import "."
import "services"

// Entry point of the plugin (manifest: entryPoints.bar). The shell host loads
// this Item and injects the properties below; we declare them so injection
// doesn't warn, even though the island doesn't use them yet.
Item {
  id: root

  property var barConfig: ({})
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property string omarchyPath: ""
  property bool rig: false              // true only in the test rig
  Component.onCompleted: Cmd.dryRun = rig   // rig never runs power commands for real

  // One Island window per screen. When monitors are plugged/unplugged,
  // Variants creates/destroys the matching windows for us.
  Variants {
    model: Quickshell.screens
    delegate: Island { rig: root.rig }
  }

  // Scriptable control. In the shell: `omarchy-shell island toggle power`.
  // In the rig: `qs ipc -p rig.qml call island toggle power`.
  Loader { source: root.rig ? "ipc/PlainIpc.qml" : "ipc/HostIpc.qml" }

  // One Hyprland global shortcut per widget. Bind a key to it in bindings.lua:
  //   o.bind("SUPER + CTRL + Q", "Power", hl.dsp.global("island:power"))
  // The keypress goes straight to this process: nothing is spawned.
  Variants {
    model: ["home", "wifi", "bluetooth", "audio", "display", "battery", "calendar",
            "worldclock", "power", "notifications", "media", "system", "tray", "theme"]
    GlobalShortcut {
      required property string modelData
      appid: "island"
      name: modelData
      description: "Toggle the island " + modelData + " widget"
      onPressed: IslandState.toggleWidget(modelData, "")
    }
  }

  // Charger plug/unplug shows a HUD. `armed` skips the value the service
  // reports at startup, which is not a real plug event.
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
