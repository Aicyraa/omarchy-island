import QtQuick
import qs.Commons
import "../Core"

// `omarchy toggle bar` flips a flag file and then calls `omarchy-shell omarchy.bar
// syncHidden` to make the bar re-read it. Answering that target keeps the stock
// show/hide key working with the island.
ShellIpc {
  target: "omarchy.bar"
  function syncHidden(): void { IslandState.syncHidden() }
}
