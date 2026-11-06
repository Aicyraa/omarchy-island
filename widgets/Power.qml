import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Power: Shutdown, Reboot, Sleep, Lock.
// Keys: 1-4 pick a tile, arrows/Tab move, Enter confirms, Esc closes (Island).
// Shutdown/Reboot are destructive: they need a second step (Enter, the same number
// again, or click-and-hold 600 ms). Sleep and Lock run immediately.
WidgetPanel {
  id: root
  preferredWidth: 660
  hint: hibernate ? "1-4 pick · ←/→ move · Enter confirm · H hibernate · Esc close"
                  : "1-4 pick · ←/→ move · Enter confirm · Esc close"

  property int sel: 3                     // starts on Lock, the safest action
  property bool hibernate: false          // only true if the system really supports it
  property string uptime: ""
  property bool restartNeeded: false

  readonly property var actions: [
    { icon: "power",   title: "Shutdown", destructive: true,  cmd: ["omarchy-system", "shutdown"] },
    { icon: "restart", title: "Reboot",   destructive: true,  cmd: ["omarchy-system", "reboot"] },
    // Sleep locks first (Omarchy also hooks the lock into suspend itself).
    { icon: "moon",    title: "Sleep",    destructive: false, cmd: ["bash", "-c", "omarchy-system-lock; systemctl suspend"] },
    { icon: "lock",    title: "Lock",     destructive: false, cmd: ["omarchy-system-lock"] }
  ]
  function run(i) { Cmd.run(actions[i].cmd); IslandState.closeWidget() }
  // A number key: pick the tile. Non-destructive tiles run at once; a destructive
  // one runs only if it was ALREADY selected (same number twice).
  function pick(i) {
    if (!actions[i].destructive) { sel = i; run(i); return }
    if (sel === i) run(i); else sel = i
  }
  Keys.onPressed: function (e) {
    if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) { pick(e.key - Qt.Key_1); e.accepted = true }
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { sel = (sel + 3) % 4; e.accepted = true }
    else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { sel = (sel + 1) % 4; e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { run(sel); e.accepted = true }
    else if (e.key === Qt.Key_H && hibernate) { Cmd.run(["bash", "-c", "omarchy-system-lock; systemctl hibernate"]); IslandState.closeWidget(); e.accepted = true }
  }

  Item { width: parent.width; height: 28
    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Power"; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong }
    Row { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Rectangle { visible: root.restartNeeded; height: 20; width: badge.width + 16; radius: 10; color: Theme.warning
        Text { id: badge; anchors.centerIn: parent; textFormat: Text.PlainText; text: "Restart needed"; color: Theme.textOnWarning; font.pixelSize: 10; font.weight: Theme.weightLabel } }
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: root.uptime; color: Theme.textMuted; font.pixelSize: 12 } }
  }

  Row {
    width: parent.width; spacing: Theme.s12
    Repeater {
      model: root.actions
      delegate: Tile {
        required property var modelData
        required property int index
        width: (parent.width - 3 * Theme.s12) / 4
        compact: true
        icon: modelData.icon; title: modelData.title
        selected: root.sel === index; danger: modelData.destructive
        holdMs: modelData.destructive ? 600 : 0
        subtitle: modelData.destructive ? "Hold to confirm"
                  : "Runs now"
        onClicked: { if (modelData.destructive) root.sel = index; else root.pick(index) }
        onHeld: root.run(index)
      }
    }
  }

  // ---- data: runs only while this widget is loaded ----
  Process { running: true; command: ["omarchy-hibernation-available"]; onExited: function (code) { root.hibernate = (code === 0) } }
  Process { running: true; command: ["awk", "{print int($1)}", "/proc/uptime"]
    stdout: StdioCollector { onStreamFinished: {
      var s = parseInt(text.trim()); if (isNaN(s)) return
      var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
      root.uptime = "up " + (d > 0 ? d + "d " : "") + (h > 0 || d > 0 ? h + "h " : "") + m + "m" } } }
  // Limited check: the running kernel's modules are gone => a reboot is pending.
  Process { running: true; command: ["bash", "-c", "[ -d /usr/lib/modules/$(uname -r) ] || echo restart"]
    stdout: StdioCollector { onStreamFinished: root.restartNeeded = text.indexOf("restart") >= 0 } }
}
