import QtQuick
import Quickshell.Io
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"

// Same API as HostIpc.qml for the standalone test rig, where qs.Commons does
// not exist. Keep the two files in sync.
IpcHandler {
  target: "island"
  function toggle(name: string): void { IslandState.toggleWidget(name, "") }
  function open(name: string): void { IslandState.openWidget(name, "") }
  function close(): void { IslandState.closeWidget() }
  function hud(kind: string, value: real): void { IslandState.showHud(kind, value, "", 0) }
  function hudJson(payload: string): void { IslandState.showHudPayload(payload) }
  function reducedMotion(on: bool): void { ConfigStore.reducedMotion = on }
  function lastCommand(): string { return Cmd.last }
  function dryRun(): string { return Cmd.dryRun ? "yes" : "no" }
  // `debug layout` toggles the overlay, `debug measure` returns JSON, `debug off` hides it.
  function debug(what: string): string {
    if (what === "layout") { IslandState.debugLayout = !IslandState.debugLayout; return IslandState.debugLayout ? "on" : "off" }
    if (what === "off") { IslandState.debugLayout = false; return "off" }
    if (what === "measure") { IslandState.measureRequested(); return IslandState.measureResult }
    if (what === "contrast") {
      const ground = Tokens.groundOf(Tokens.surfaceStyle)
      const pairs = [
        ["text/ground", Tokens.color.text, ground],
        ["text/surface", Tokens.color.text, Tokens.color.surface],
        ["text/surfaceRaised", Tokens.color.text, Tokens.color.surfaceRaised],
        ["textMuted/ground", Tokens.color.textMuted, ground],
        ["textMuted/surface", Tokens.color.textMuted, Tokens.color.surface],
        ["textMuted/surfaceRaised", Tokens.color.textMuted, Tokens.color.surfaceRaised],
        ["onAccent/accent", Tokens.color.onAccent, Tokens.color.accent],
        ["accent/surface", Tokens.color.accent, Tokens.color.surface],
        ["accent/ground", Tokens.color.accent, ground],
        ["success/surface", Tokens.color.success, Tokens.color.surface],
        ["warning/surface", Tokens.color.warning, Tokens.color.surface],
        ["danger/surface", Tokens.color.danger, Tokens.color.surface]
      ]
      return JSON.stringify(pairs.map(function (p) {
        const r = Palettes.contrastRatio(p[1], p[2])
        return { pair: p[0], ratio: +r.toFixed(2), pass: r >= 4.5, fg: String(p[1]), bg: String(p[2]) }
      }))
    }
    // Test hooks: inject the hover event a real pointer produces over the focused screen's pill.
    if (what === "trace") { IslandState.debugTrace = !IslandState.debugTrace; return IslandState.debugTrace ? "trace on" : "trace off" }
    if (what === "stats") return JSON.stringify({ cpu: Stats.cpu, mem: Stats.memUsedGb, temp: Stats.temp, n: Stats.cpuHist.length, active: Stats.active })
    if (what === "fake-rec") { Indicators.recording = !Indicators.recording; return Indicators.recording ? "rec on (until the next refresh)" : "rec off" }
    if (what === "zones") return JSON.stringify(IslandState.zoneRects)
    if (what === "indicators") return JSON.stringify({ dnd: Indicators.dnd, night: Indicators.nightLight, awake: Indicators.stayAwake, dictation: Indicators.dictation })
    if (what === "toggle-awake") { Indicators.toggleStayAwake(); return "toggled" }
    if (what === "hover-on") { IslandState.hoverIntent(true, IslandState.focusedScreenName()); return "hover on" }
    if (what === "hover-off") { IslandState.hoverIntent(false, IslandState.focusedScreenName()); return "hover off" }
    return "usage: debug layout|measure|contrast|off"
  }
  function mode(): string { return IslandState.mode }
  // The menu: `openMenu` takes the same JSON as the stock menu's summon payload (a route, or a dmenu request with
  // mode select|input, options, selectionFile, doneFile). `menuRefresh` re-reads the tree; `menuState` reports the request.
  function openMenu(payload: string): void { MenuData.openFromPayload(payload) }
  function menuRefresh(): void { MenuData.refresh() }
  // Closes the menu if it is the open widget (the menu shim calls this on the shell's hide).
  function closeMenu(): void { MenuData.close() }
  function menuState(): string {
    return JSON.stringify({ request: MenuData.request.active === true, mode: MenuData.request.mode || "", route: MenuData.pendingRoute, revision: MenuData.revision })
  }
}
