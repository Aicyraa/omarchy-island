import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Power: focused action dock with only the six square controls (Lock, Sleep, Screensaver,
// Reboot, Shutdown, Logout) arranged in a flexible Flow without bottom subtitle text or
// secondary system stats.
// Keys: 1-6 pick a tile, arrows/Tab move, Enter confirms, H hibernate (if supported), Esc close.
WidgetPanel {
  id: root
  preferredWidth: 668
  hint: hibernate ? "1-6 pick · ←/→ move · Enter confirm · H hibernate · Esc close"
                  : "1-6 pick · ←/→ move · Enter confirm · Esc close"

  property int sel: 0
  property bool hibernate: false
  property bool restartNeeded: false

  readonly property var actions: [
    { icon: "lock",    title: "Lock",        destructive: false, cmd: ["omarchy-system-lock"] },
    { icon: "moon",    title: "Sleep",       destructive: false, cmd: ["bash", "-c", "omarchy-system-lock; systemctl suspend"] },
    { icon: "eye",     title: "Screensaver", destructive: false, cmd: ["omarchy-launch-screensaver", "force"] },
    { icon: "restart", title: "Reboot",      destructive: true,  cmd: ["omarchy-system", "reboot"] },
    { icon: "power",   title: "Shutdown",    destructive: true,  cmd: ["omarchy-system", "shutdown"] },
    { icon: "logout",  title: "Logout",      destructive: true,  cmd: ["omarchy-system", "logout"] }
  ]
  function run(i) { Cmd.run(actions[i].cmd); IslandState.closeWidget() }
  function pick(i) {
    if (!actions[i].destructive) { sel = i; run(i); return }
    if (sel === i) run(i); else sel = i
  }
  Keys.onPressed: function (e) {
    var n = actions.length
    if (e.key >= Qt.Key_1 && e.key < Qt.Key_1 + n) { pick(e.key - Qt.Key_1); e.accepted = true }
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { sel = (sel + n - 1) % n; e.accepted = true }
    else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { sel = (sel + 1) % n; e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { run(sel); e.accepted = true }
    else if (e.key === Qt.Key_H && hibernate) { Cmd.run(["bash", "-c", "omarchy-system-lock; systemctl hibernate"]); IslandState.closeWidget(); e.accepted = true }
  }

  // Only shown when a kernel upgrade left running modules missing.
  Rectangle {
    antialiasing: true; visible: root.restartNeeded; height: 22; width: badge.width + 20; radius: 11; color: Theme.warning
    Text { id: badge; anchors.centerIn: parent; textFormat: Text.PlainText; text: "Restart needed"; color: Theme.textOnWarning; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
  }

  // Six compact square action containers in a flexible flow, without bottom subtitle text.
  Flow {
    width: parent.width
    spacing: Theme.s12
    Repeater {
      model: root.actions
      delegate: Tile {
        required property var modelData
        required property int index
        compact: true
        width: 96; height: 96
        icon: modelData.icon; title: modelData.title
        subtitle: ""
        selected: root.sel === index; danger: modelData.destructive
        holdMs: modelData.destructive ? 600 : 0
        onClicked: { if (modelData.destructive) root.sel = index; else root.pick(index) }
        onHeld: root.run(index)
      }
    }
  }

  Process { running: true; command: ["omarchy-hibernation-available"]; onExited: function (code) { root.hibernate = (code === 0) } }
  Process {
    running: true; command: ["bash", "-c", "[ -d /usr/lib/modules/$(uname -r) ] || echo restart"]
    stdout: StdioCollector { onStreamFinished: root.restartNeeded = text.indexOf("restart") >= 0 }
  }
}
