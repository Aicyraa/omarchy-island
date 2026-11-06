pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Indicators: on/off state of Omarchy's toggles, read in ONE batched process
// whenever something changes. Nothing polls: refresh() is called at startup, when a
// widget opens/closes, after the island toggles something itself, and by Omarchy's
// own scripts via `omarchy-shell omarchy.indicators refresh`.
Singleton {
  id: root
  property bool dnd: false
  property bool nightLight: false
  property bool stayAwake: false
  property bool recording: false
  property real recSeconds: 0
  property string dictation: "idle"
  property bool dictationAvailable: false
  property bool updateAvailable: false
  property real updateCheckedAt: 0

  function refresh() { if (!reader.running) reader.running = true }

  Process {
    id: reader
    command: ["bash", "-c",
      "echo dnd=$(omarchy-shell -q notifications isDnd 2>/dev/null);" +
      "echo night=$(omarchy-toggle-nightlight --status 2>/dev/null | jq -r '.enabled' 2>/dev/null);" +
      "[ -f \"$HOME/.local/state/omarchy/indicators/stay-awake\" ] && echo awake=1 || echo awake=0;" +
      "p=$(pgrep -f '^gpu-screen-recorder' | head -1); if [ -n \"$p\" ]; then echo rec=1; echo recsec=$(ps -o etimes= -p $p | tr -d ' '); else echo rec=0; fi;" +
      "if command -v voxtype >/dev/null; then echo dictavail=1; echo dict=$(timeout 2 voxtype status 2>/dev/null | head -1); else echo dictavail=0; fi"]
    stdout: StdioCollector { onStreamFinished: {
      var kv = {}
      text.split("\n").forEach(function (l) { var i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1).trim() })
      root.dnd = kv.dnd === "on"
      root.nightLight = kv.night === "true"
      root.stayAwake = kv.awake === "1"
      root.recording = kv.rec === "1"
      root.recSeconds = parseInt(kv.recsec || "0") || 0
      root.dictationAvailable = kv.dictavail === "1"
      root.dictation = kv.dict || "idle"
    } }
  }

  // Update check hits the package database, so it runs at most every 30 minutes.
  function checkUpdates() {
    if (Date.now() - updateCheckedAt < 30 * 60 * 1000 || updater.running) return
    updateCheckedAt = Date.now(); updater.running = true
  }
  Process {
    id: updater
    command: ["omarchy-update-available"]
    onExited: function (code) { root.updateAvailable = (code === 0) }
  }

  // Toggle helpers: run the Omarchy command, then re-read state shortly after.
  function act(argv) { Cmd.run(argv); settle.restart() }
  Timer { id: settle; interval: 450; onTriggered: root.refresh() }
  function toggleDnd() { act(["omarchy-shell", "-q", "notifications", "toggleDnd"]) }
  function toggleNightLight() { act(["omarchy-toggle-nightlight"]) }
  function toggleStayAwake() { act(["omarchy-toggle-idle", "toggle"]) }
  function toggleDictation() { act(["omarchy-dictation", "toggle"]) }
}
