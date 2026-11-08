import QtQuick
import Quickshell
import qs.Commons

// Replaces omarchy.menu (the shell sends every summon/toggle of "omarchy.menu" to an enabled plugin that declares
// `clonedFrom: "omarchy.menu"`). It draws nothing: it forwards the payload to the island, which shows the menu as its
// Menu widget. The payload is the stock one: a route ({"menu": "system"}) or a dmenu request (mode select|input,
// options, selectionFile, doneFile), so Omarchy's scripts that use dmenu keep working.
//
// `opened` tells the shell whether to hide or summon on the next toggle. The island closes the menu itself (Esc, click
// outside, an action), so the island tells this plugin when it closes: `omarchy-shell -q menu closed` (see Menu.qml in
// the island, Component.onDestruction).
Item {
  id: root
  property bool opened: false

  function forward(args) { Quickshell.execDetached(["omarchy-shell", "-q", "island"].concat(args)) }
  function open(payloadJson) { opened = true; forward(["openMenu", payloadJson || "{}"]) }
  function close() { opened = false; forward(["closeMenu"]) }
  function refresh() { forward(["menuRefresh"]); return "ok" }

  ShellIpc {
    target: "menu"
    function open(payloadJson: string): string { root.open(payloadJson); return "ok" }
    function close(): string { root.close(); return "ok" }
    function refresh(): string { return root.refresh() }
    function closed(): string { root.opened = false; return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }
}
