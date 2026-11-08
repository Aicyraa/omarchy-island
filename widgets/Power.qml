import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Power: Lock, Sleep, Screensaver, Logout, Reboot, Shutdown. Replaces the menu's System section (the menu redirects to it).
// Keys: 1-6 pick a tile, arrows/Tab move, Enter confirms, Esc closes (Island).
// Logout, Reboot and Shutdown are destructive: they need a second step (Enter, the same number
// again, or click-and-hold 600 ms). Lock, Sleep and Screensaver run immediately.
WidgetPanel {
  id: root
  preferredWidth: 660
  hint: hibernate ? "1-6 pick · ←/→ move · Enter confirm · H hibernate · Esc close"
                  : "1-6 pick · ←/→ move · Enter confirm · Esc close"

  property int sel: 0                     // starts on Lock, the safest action
  property bool hibernate: false          // only true if the system really supports it
  property bool restartNeeded: false
  property string booted: ""
  property string kernel: ""
  property string profile: ""
  property string session: ""

  readonly property var actions: [
    { icon: "lock",    title: "Lock",        destructive: false, cmd: ["omarchy-system-lock"] },
    // Sleep locks first (Omarchy also hooks the lock into suspend itself).
    { icon: "moon",    title: "Sleep",       destructive: false, cmd: ["bash", "-c", "omarchy-system-lock; systemctl suspend"] },
    { icon: "eye",     title: "Screensaver", destructive: false, cmd: ["omarchy-launch-screensaver", "force"] },
    { icon: "logout",  title: "Logout",      destructive: true,  cmd: ["omarchy-system", "logout"] },
    { icon: "restart", title: "Reboot",      destructive: true,  cmd: ["omarchy-system", "reboot"] },
    { icon: "power",   title: "Shutdown",    destructive: true,  cmd: ["omarchy-system", "shutdown"] }
  ]
  function run(i) { Cmd.run(actions[i].cmd); IslandState.closeWidget() }
  // A number key: pick the tile. Non-destructive tiles run at once; a destructive
  // one runs only if it was ALREADY selected (same number twice).
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

  // Only shown when a reboot is pending (the kernel's modules are gone).
  Rectangle { antialiasing: true; visible: root.restartNeeded; height: 22; width: badge.width + 20; radius: 11; color: Theme.warning
    Text { id: badge; anchors.centerIn: parent; textFormat: Text.PlainText; text: "Restart needed"; color: Theme.textOnWarning; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel } }

  // Asymmetric: Lock and Sleep in a narrow column on the left, the other four in a 2 x 2 grid on the right.
  // Both sides are the same height, so the block reads as one shape.
  readonly property real colW: (width - Theme.s12) * 0.4
  readonly property real gridW: width - Theme.s12 - colW
  Row {
    width: parent.width; spacing: Theme.s12
    Column {
      width: root.colW; spacing: Theme.s12
      Repeater {
        model: 2
        delegate: Tile {
          required property int index
          width: parent.width
          icon: root.actions[index].icon; title: root.actions[index].title
          selected: root.sel === index; danger: root.actions[index].destructive
          holdMs: root.actions[index].destructive ? 600 : 0
          subtitle: root.actions[index].destructive ? "Hold" : "Runs now"
          onClicked: { if (root.actions[index].destructive) root.sel = index; else root.pick(index) }
          onHeld: root.run(index)
        }
      }
    }
    Grid {
      columns: 2; spacing: Theme.s12
      width: root.gridW
      Repeater {
        model: 4
        delegate: Tile {
          required property int index
          readonly property int gi: index + 2
          width: (parent.width - Theme.s12) / 2
          icon: root.actions[gi].icon; title: root.actions[gi].title
          selected: root.sel === gi; danger: root.actions[gi].destructive
          holdMs: root.actions[gi].destructive ? 600 : 0
          subtitle: root.actions[gi].destructive ? "Hold" : "Runs now"
          onClicked: { if (root.actions[gi].destructive) root.sel = gi; else root.pick(gi) }
          onHeld: root.run(gi)
        }
      }
    }
  }

  // ---- details ----
  Flow {
    width: parent.width; spacing: Theme.s12
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Battery"; fraction: Power.present ? Power.level : -1
      value: Power.present ? Math.round(Power.level * 100) + "%" + (Power.charging ? " · charging" : "") + (Power.secondsLeft > 0 ? " · " + Power.timeText(Power.secondsLeft) : "") : "No battery" }
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Power profile"; value: root.profile !== "" ? root.profile : "—" }
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Updates"; value: Indicators.updateAvailable ? "Update available" : "Up to date" }
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Last boot"; value: root.booted !== "" ? root.booted : "—" }
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Kernel"; value: root.kernel !== "" ? root.kernel : "—" }
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Session"; value: root.session !== "" ? root.session : "—" }
  }

  // ---- data: runs only while this widget is loaded ----
  Process { running: true
    command: ["bash", "-c", "uptime -s; uname -r; powerprofilesctl get 2>/dev/null; echo \"$USER@$(hostname)\""]
    stdout: StdioCollector { onStreamFinished: {
      var l = text.split("\n")
      var d = new Date((l[0] || "").replace(" ", "T"))
      root.booted = isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "ddd d MMM, HH:mm")
      root.kernel = l[1] || ""
      var pr = l[2] || ""; root.profile = pr === "power-saver" ? "Saver" : pr === "performance" ? "Performance" : pr === "balanced" ? "Balanced" : pr
      root.session = l[3] || "" } } }
  Process { running: true; command: ["omarchy-hibernation-available"]; onExited: function (code) { root.hibernate = (code === 0) } }
  // Limited check: the running kernel's modules are gone => a reboot is pending.
  Process { running: true; command: ["bash", "-c", "[ -d /usr/lib/modules/$(uname -r) ] || echo restart"]
    stdout: StdioCollector { onStreamFinished: root.restartNeeded = text.indexOf("restart") >= 0 } }
}
