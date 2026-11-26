import QtQuick
import Quickshell
import qs.Commons

// Replaces omarchy.osd (the shell sends every `summon("omarchy.osd")` to an
// enabled plugin that declares `clonedFrom: "omarchy.osd"`). It draws nothing:
// it forwards the payload to the island, which shows it as a HUD.
//
// Two routes reach the OSD in stock Omarchy, and this handles both:
//   1. omarchy-osd / omarchy-audio-output-volume -> `omarchy-shell osd show <json>`
//   2. the shell itself (brightness keys, panels) -> summon() -> open(<json>)
Item {
  id: root
  property bool opened: false   // the shell reads this to decide toggle vs summon

  function forward(payloadJson) {
    // execDetached: fire-and-forget, nothing for us to clean up.
    Quickshell.execDetached(["omarchy-shell", "-q", "island", "hudJson", payloadJson || "{}"])
  }
  function open(payloadJson) { forward(payloadJson) }
  function close() {}

  ShellIpc {
    target: "osd"
    function show(payloadJson: string): string { root.forward(payloadJson); return "ok" }
    function close(): string { return "ok" }
    function state(): string { return "closed" }
    function ping(): string { return "ok" }
  }
}
