import QtQuick
import Quickshell.Io
import ".."
import "../services"

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
  function lastCommand(): string { return Cmd.last }
  function hints(): string { return IslandState.hintsVisible ? "on" : "off" }
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
