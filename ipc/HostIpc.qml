import QtQuick
import qs.Commons
import ".."

// IPC inside the real Omarchy shell. `ShellIpc` is an IpcHandler that the
// shell ALSO answers over its own socket, so `omarchy-shell island ...`
// costs ~5ms instead of the ~45ms a `qs ipc` client takes. That matters for
// the HUD, which is called on every volume/brightness key repeat.
ShellIpc {
  target: "island"
  function toggle(name: string): void { IslandState.toggleWidget(name, "") }
  function open(name: string): void { IslandState.openWidget(name, "") }
  function close(): void { IslandState.closeWidget() }
  function hud(kind: string, value: real): void { IslandState.showHud(kind, value, "", 0) }
  function hudJson(payload: string): void { IslandState.showHudPayload(payload) }
  function reducedMotion(on: bool): void { IslandState.reducedMotion = on }
  function mode(): string { return IslandState.mode }
}
