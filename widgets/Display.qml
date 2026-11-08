import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Display: brightness, night light, text size, and the hardware switches that Trigger > Hardware had in the menu:
// laptop display on/off and mirroring (laptops only), touchpad and touchscreen (when the machine has one).
// Rows the machine does not have are skipped. Keys: ↑/↓ move, ←/→ adjust, Enter toggle.
WidgetPanel {
  id: root
  preferredWidth: 460
  hint: "↑/↓ move · ←/→ adjust · Enter toggle · Esc close"

  // Rows: 0 brightness, 1 night light, 2 text size, 3 laptop display, 4 mirroring, 5 touchpad, 6 touchscreen.
  property int row: 0
  property int textSize: 12
  readonly property int lastRow: 6

  // Hardware and the state of its switches, read from the same things Omarchy's menu checked: the hardware helpers and
  // the Hyprland toggle flags (a flag file present means the switch is on, which for the display and the input devices
  // means disabled or mirrored).
  property bool hwLaptop: false
  property bool hwTouchpad: false
  property bool hwTouchscreen: false
  property bool laptopOff: false
  property bool mirrorOn: false
  property bool touchpadOff: false
  property bool touchscreenOff: false

  Component.onCompleted: { Brightness.refresh(); Indicators.refresh() }
  function setText(n) { textSize = Math.max(8, Math.min(24, n)); Cmd.run(["omarchy-display-text-size", String(textSize)]) }

  function rowVisible(r) {
    if (r === 3 || r === 4) return hwLaptop
    if (r === 5) return hwTouchpad
    if (r === 6) return hwTouchscreen
    return true
  }
  function step(d) {
    var r = row + d
    while (r >= 0 && r <= lastRow && !rowVisible(r)) r += d
    if (r >= 0 && r <= lastRow) row = r
  }
  // Switch a hardware row, then read the state again once the helper has applied it.
  function toggleHw(r) {
    if (r === 3) Cmd.run(["omarchy-hyprland-monitor-internal", "toggle"])
    else if (r === 4) Cmd.run(["omarchy-hyprland-monitor-internal-mirror", "toggle"])
    else if (r === 5) Cmd.run(["omarchy-toggle-touchpad"])
    else if (r === 6) Cmd.run(["omarchy-toggle-touchscreen"])
    else return
    reprobe.restart()
  }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { step(1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { step(-1); e.accepted = true }
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
      var d = e.key === Qt.Key_Right ? 1 : -1
      if (row === 0) Brightness.set(Brightness.level + d * 0.05)
      else if (row === 2) setText(textSize + d)
      e.accepted = true
    }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
      if (row === 1) Indicators.toggleNightLight()
      else if (row >= 3) toggleHw(row)
      e.accepted = true
    }
  }

  Timer { id: reprobe; interval: 800; onTriggered: hwProbe.running = true }
  Process {
    id: hwProbe
    running: true
    command: ["bash", "-c", 'h="$HOME/.local/state/omarchy/toggles/hypr"; '
      + 'omarchy-hw-laptop && echo laptop=1 || echo laptop=0; '
      + '[ -n "$(omarchy-hw-touchpad 2>/dev/null)" ] && echo touchpad=1 || echo touchpad=0; '
      + '[ -n "$(omarchy-hw-touchscreen 2>/dev/null)" ] && echo touchscreen=1 || echo touchscreen=0; '
      + '[ -f "$h/internal-monitor-disable.lua" ] && echo laptopOff=1 || echo laptopOff=0; '
      + '[ -f "$h/internal-monitor-mirror.lua" ] && echo mirror=1 || echo mirror=0; '
      + '[ -f "$h/touchpad-disabled-name" ] && echo touchpadOff=1 || echo touchpadOff=0; '
      + '[ -f "$h/touchscreen-disabled-name" ] && echo touchscreenOff=1 || echo touchscreenOff=0']
    stdout: StdioCollector { onStreamFinished: {
      var v = ({})
      String(text || "").split("\n").forEach(function (l) { var i = l.indexOf("="); if (i > 0) v[l.slice(0, i)] = l.slice(i + 1) === "1" })
      root.hwLaptop = !!v.laptop; root.hwTouchpad = !!v.touchpad; root.hwTouchscreen = !!v.touchscreen
      root.laptopOff = !!v.laptopOff; root.mirrorOn = !!v.mirror
      root.touchpadOff = !!v.touchpadOff; root.touchscreenOff = !!v.touchscreenOff
    } }
  }

  PillSlider {
    width: parent.width; icon: "sun"; value: Brightness.level; visible: Brightness.available
    selected: root.row === 0; showValue: true
    onMoved: function (v) { root.row = 0; Brightness.set(v) }
  }
  Text { visible: !Brightness.available; textFormat: Text.PlainText
    text: "No controllable backlight"; color: Theme.textMuted; font.pixelSize: Theme.typeBody }
  Tile {
    width: parent.width
    icon: "moon"; title: "Night light"; subtitle: Indicators.nightLight ? "On" : "Off"
    on: Indicators.nightLight; selected: root.row === 1
    onClicked: { root.row = 1; Indicators.toggleNightLight() }
  }
  // Hardware switches (each row shows only when the machine has the device)
  Tile {
    visible: root.hwLaptop; width: parent.width
    icon: "monitor"; title: "Laptop display"; subtitle: root.laptopOff ? "Off" : "On"
    on: !root.laptopOff; selected: root.row === 3
    onClicked: { root.row = 3; root.toggleHw(3) }
  }
  Tile {
    visible: root.hwLaptop; width: parent.width
    icon: "mirror"; title: "Mirror to external"; subtitle: root.mirrorOn ? "On" : "Off"
    on: root.mirrorOn; selected: root.row === 4
    onClicked: { root.row = 4; root.toggleHw(4) }
  }
  Tile {
    visible: root.hwTouchpad; width: parent.width
    icon: "mouse"; title: "Touchpad"; subtitle: root.touchpadOff ? "Off" : "On"
    on: !root.touchpadOff; selected: root.row === 5
    onClicked: { root.row = 5; root.toggleHw(5) }
  }
  Tile {
    visible: root.hwTouchscreen; width: parent.width
    icon: "phone"; title: "Touchscreen"; subtitle: root.touchscreenOff ? "Off" : "On"
    on: !root.touchscreenOff; selected: root.row === 6
    onClicked: { root.row = 6; root.toggleHw(6) }
  }
  // Text size stepper: − 12 px +
  Rectangle {
    width: parent.width; height: Theme.tileHeight; radius: height / 2; color: Theme.surface
    border.width: root.row === 2 ? 2 : 0; border.color: Theme.text
    Icon { x: Theme.s16 + 2; anchors.verticalCenter: parent.verticalCenter; name: "type"; size: Theme.iconMd }
    Text { x: Theme.s16 + 2 + Theme.iconMd + Theme.s12; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
      text: "Text size"; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightLabel }
    Row {
      anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Rectangle { antialiasing: true; width: 34; height: 34; radius: 17; color: Theme.surfaceRaised
        Icon { anchors.centerIn: parent; name: "chevron-left"; size: Theme.iconSm }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.row = 2; root.setText(root.textSize - 1) } } }
      Text { width: 44; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText; text: root.textSize + " px"; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightLabel }
      Rectangle { antialiasing: true; width: 34; height: 34; radius: 17; color: Theme.surfaceRaised
        Icon { anchors.centerIn: parent; name: "chevron-right"; size: Theme.iconSm }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.row = 2; root.setText(root.textSize + 1) } } }
    }
  }

  Process {
    running: true
    command: ["omarchy-display-text-size"]
    stdout: StdioCollector { onStreamFinished: { var m = /text size:\s*(\d+)/.exec(text); if (m) root.textSize = parseInt(m[1]) } }
  }
}
