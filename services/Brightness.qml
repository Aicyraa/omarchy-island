pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Brightness: read once with brightnessctl when a widget opens (no polling),
// write through Omarchy's own wrapper so multi-monitor/DDC setups still work.
Singleton {
  id: root
  property real level: 0            // 0..1
  property bool available: false

  Process {
    id: reader
    command: ["brightnessctl", "-m", "-c", "backlight"]
    // -m prints "device,class,current,percent%,max"
    stdout: StdioCollector { onStreamFinished: {
      var f = text.trim().split("\n")[0].split(",")
      var pct = f.length >= 4 ? parseInt(f[3]) : NaN
      root.available = !isNaN(pct)
      if (root.available && !writer.pending) root.level = pct / 100
    } }
  }
  function refresh() { if (!reader.running) reader.running = true }

  // Dragging a slider fires many changes; a short debounce sends only the last.
  QtObject { id: writer; property bool pending: false }
  function set(frac) { level = Math.max(0.01, Math.min(1, frac)); writer.pending = true; debounce.restart() }
  Timer {
    id: debounce; interval: 70
    onTriggered: { Cmd.run(["omarchy-brightness-display", "--no-osd", Math.round(root.level * 100) + "%"]); writer.pending = false }
  }
}
