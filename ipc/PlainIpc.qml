import QtQuick
import Quickshell.Io
import ".."

// Same API as HostIpc.qml for the standalone test rig, where qs.Commons does
// not exist. Keep the two files in sync.
IpcHandler {
  target: "island"
  function toggle(name: string): void { IslandState.toggleWidget(name, "") }
  function open(name: string): void { IslandState.openWidget(name, "") }
  function close(): void { IslandState.closeWidget() }
  function hud(kind: string, value: real): void { IslandState.showHud(kind, value, "", 0) }
  function hudJson(payload: string): void { IslandState.showHudPayload(payload) }
  function reducedMotion(on: bool): void { IslandState.reducedMotion = on }
  function mode(): string { return IslandState.mode }
}
