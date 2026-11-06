import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Power widget: Shutdown, Reboot, Sleep, Lock.
//
// Keys: 1-4 pick a tile, arrows/Tab move the selection, Enter confirms, Esc
// closes (Esc is handled by Island). Shutdown/Reboot are destructive: they need
// a second step (Enter, the same number again, or click-and-hold 600 ms).
// Sleep and Lock run immediately.
Item {
  id: root
  focus: true
  property string hint: hibernate ? "1-4 pick · ←/→ move · Enter confirm · H hibernate · Esc close"
                                  : "1-4 pick · ←/→ move · Enter confirm · Esc close"

  // Which tile has the selection ring. Starts on Lock, the safest action.
  property int sel: 3
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

  // A number key: pick the tile. Non-destructive tiles run at once; a
  // destructive one runs only if it was ALREADY selected (same number twice).
  function pick(i) {
    if (!actions[i].destructive) { sel = i; run(i); return }
    if (sel === i) run(i); else sel = i
  }

  Keys.onPressed: function (e) {
    if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) { pick(e.key - Qt.Key_1); e.accepted = true }
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { sel = (sel + 3) % 4; e.accepted = true }
    else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { sel = (sel + 1) % 4; e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { run(sel); e.accepted = true }
    else if (e.key === Qt.Key_H && hibernate) {
      Cmd.run(["bash", "-c", "omarchy-system-lock; systemctl hibernate"]); IslandState.closeWidget(); e.accepted = true
    }
  }

  // ---- header: title, uptime, restart badge ----
  Text {
    x: 22; y: 16
    textFormat: Text.PlainText; text: "Power"
    color: Theme.text; font.pixelSize: 15; font.bold: true
  }
  Row {
    anchors.right: parent.right; anchors.rightMargin: 22; y: 16
    spacing: 10
    Rectangle {
      visible: root.restartNeeded
      height: 20; width: badge.width + 16; radius: 10; color: Theme.warning
      Text { id: badge; anchors.centerIn: parent; textFormat: Text.PlainText
        text: "Restart needed"; color: Theme.background; font.pixelSize: 10; font.bold: true }
    }
    Text {
      textFormat: Text.PlainText; text: root.uptime
      color: Theme.textMuted; font.pixelSize: 12
    }
  }

  // ---- the four tiles ----
  Row {
    x: 22; y: 50
    spacing: 12
    Repeater {
      model: root.actions
      delegate: Tile {
        required property var modelData
        required property int index
        width: (root.width - 44 - 36) / 4; height: 120
        compact: true
        icon: modelData.icon; title: modelData.title
        keyHint: String(index + 1)
        selected: root.sel === index
        danger: modelData.destructive
        holdMs: modelData.destructive ? 600 : 0
        subtitle: modelData.destructive
          ? (selected ? "Enter to confirm" : "Hold to confirm") : "Runs now"
        onClicked: { if (modelData.destructive) root.sel = index; else root.pick(index) }
        onHeld: root.run(index)
      }
    }
  }

  // ---- hibernate chip: only if the system actually supports hibernation ----
  Rectangle {
    visible: root.hibernate
    x: 22 + 2 * ((root.width - 44 - 36) / 4 + 12) + ((root.width - 44 - 36) / 8) - width / 2
    y: 182
    width: 110; height: 28; radius: 14; color: Theme.surface
    Row {
      anchors.centerIn: parent; spacing: 6
      Icon { name: "snow"; size: 14; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
      Text { textFormat: Text.PlainText; text: "Hibernate  H"; color: Theme.text; font.pixelSize: 11 }
    }
    MouseArea { anchors.fill: parent
      onClicked: { Cmd.run(["bash", "-c", "omarchy-system-lock; systemctl hibernate"]); IslandState.closeWidget() } }
  }

  // ---- data: runs only while this widget is loaded (Island unloads it on close) ----
  Process {
    running: true
    command: ["omarchy-hibernation-available"]
    onExited: function (code) { root.hibernate = (code === 0) }
  }
  Process {
    id: up
    running: true
    command: ["awk", "{print int($1)}", "/proc/uptime"]
    stdout: StdioCollector { onStreamFinished: {
      var s = parseInt(text.trim()); if (isNaN(s)) return
      var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
      root.uptime = "up " + (d > 0 ? d + "d " : "") + (h > 0 || d > 0 ? h + "h " : "") + m + "m"
    } }
  }
  // Limited check: the running kernel's modules are gone => a reboot is pending.
  Process {
    running: true
    command: ["bash", "-c", "[ -d /usr/lib/modules/$(uname -r) ] || echo restart"]
    stdout: StdioCollector { onStreamFinished: root.restartNeeded = text.indexOf("restart") >= 0 }
  }
}
