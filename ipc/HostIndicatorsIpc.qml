import QtQuick
import qs.Commons
import "../services"

// Omarchy's toggle scripts call `omarchy-shell omarchy.indicators refresh` after
// they change something. Answering that target keeps the island's indicators
// current without any polling. (The stock bar's Indicators widget used it.)
ShellIpc {
  target: "omarchy.indicators"
  function refresh(): void { Indicators.refresh() }
}
