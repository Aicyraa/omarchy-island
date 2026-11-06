import QtQuick
import Quickshell
import Quickshell.Io
import "."

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
  property bool rig: false              // true only in tools/rig

  // One Island window per screen. When monitors are plugged/unplugged,
  // Variants creates/destroys the matching windows for us.
  Variants {
    model: Quickshell.screens
    delegate: Island { rig: root.rig }
  }

  // Scriptable control: `qs -p ... ipc call island toggle power`.
  IpcHandler {
    target: "island"
    function toggle(name: string): void { IslandState.toggleWidget(name, "") }
    function open(name: string): void { IslandState.openWidget(name, "") }
    function close(): void { IslandState.closeWidget() }
    function hud(kind: string, value: real): void { IslandState.showHud(kind, value) }
    function reducedMotion(on: bool): void { IslandState.reducedMotion = on }
    function mode(): string { return IslandState.mode }
  }
}
