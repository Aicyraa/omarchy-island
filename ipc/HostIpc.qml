import QtQuick
import qs.Commons
import ".."
import "../services"

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
  function lastCommand(): string { return Cmd.last }
  function dryRun(): string { return Cmd.dryRun ? "yes" : "no" }
  // `debug layout` toggles the overlay, `debug measure` returns JSON, `debug off` hides it.
  function debug(what: string): string {
    if (what === "layout") { IslandState.debugLayout = !IslandState.debugLayout; return IslandState.debugLayout ? "on" : "off" }
    if (what === "off") { IslandState.debugLayout = false; return "off" }
    if (what === "measure") { IslandState.measureRequested(); return IslandState.measureResult }
    if (what === "contrast") return JSON.stringify(Theme.audit())
    return "usage: debug layout|measure|contrast|off"
  }
  function mode(): string { return IslandState.mode }
}
