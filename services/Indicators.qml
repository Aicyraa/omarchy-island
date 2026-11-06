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

  // A refresh asked for while one is running is QUEUED, not dropped (a dropped one left the tiles showing stale state
  // after a toggle when the hover form had just started a slow read).
  property bool again: false
  function refresh() { if (reader.running) again = true; else reader.running = true; readDict() }
  function readDict() { if (dictationAvailable && !dictReader.running) dictReader.running = true }

  Process {
    id: reader
    command: ["bash", "-c",
      "echo dnd=$(omarchy-shell -q notifications isDnd 2>/dev/null);" +
      "echo night=$(omarchy-toggle-nightlight --status 2>/dev/null | jq -r '.enabled' 2>/dev/null);" +
      "[ -f \"$HOME/.local/state/omarchy/indicators/stay-awake\" ] && echo awake=1 || echo awake=0;" +
      "p=$(pgrep -f '^gpu-screen-recorder' | head -1); if [ -n \"$p\" ]; then echo rec=1; echo recsec=$(ps -o etimes= -p $p | tr -d ' '); else echo rec=0; fi;" +
      "if command -v voxtype >/dev/null; then echo dictavail=1; else echo dictavail=0; fi"]
    stdout: StdioCollector { onStreamFinished: {
      var kv = {}
      text.split("\n").forEach(function (l) { var i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1).trim() })
      root.dnd = kv.dnd === "on"
      root.nightLight = kv.night === "true"
      root.stayAwake = kv.awake === "1"
      root.recording = kv.rec === "1"
      root.recSeconds = parseInt(kv.recsec || "0") || 0
      var avail = kv.dictavail === "1"
      if (avail && !root.dictationAvailable) { root.dictationAvailable = true; root.readDict() } else root.dictationAvailable = avail
    } }
    onExited: if (root.again) { root.again = false; running = true }
  }
  // Dictation status is the slow one (voxtype can take a second or two), so it has its own reader.
  Process {
    id: dictReader
    command: ["bash", "-c", "timeout 2 voxtype status 2>/dev/null | head -1"]
    stdout: StdioCollector { onStreamFinished: root.dictation = text.trim() || "idle" }
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
  // Flip the visible state at once; the re-read after `settle` confirms (or corrects) it.
  function toggleDnd() { dnd = !dnd; act(["omarchy-shell", "-q", "notifications", "toggleDnd"]) }
  function toggleNightLight() { nightLight = !nightLight; act(["omarchy-toggle-nightlight"]) }
  function toggleStayAwake() { stayAwake = !stayAwake; act(["omarchy-toggle-idle", "toggle"]) }
  Timer { id: settle; interval: 450; onTriggered: root.refresh() }
  function toggleDictation() { act(["omarchy-dictation", "toggle"]) }
}
