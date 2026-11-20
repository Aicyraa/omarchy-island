import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Display: asymmetrical Apple-inspired layout — dominant Brightness hero card (~64%) paired
// with an offset Night Light card (~36%), followed by the Text Size stepper and a compact
// 2-column grid of hardware switches (shown only when the machine has those devices).
// Keys: ↑/↓ move, ←/→ adjust brightness or text size, Enter toggle.
WidgetPanel {
  id: root
  preferredWidth: 540
  hint: "↑/↓ move · ←/→ adjust · Enter toggle · Esc close"

  // Visual order: 0 brightness, 1 night light, 2 text size, 3 laptop display, 4 mirror, 5 touchpad, 6 touchscreen.
  property int row: 0
  property int textSize: 12
  readonly property int lastRow: 6

  property bool hwLaptop: false
  property bool hwTouchpad: false
  property bool hwTouchscreen: false
  property bool laptopOff: false
  property bool mirrorOn: false
  property bool touchpadOff: false
  property bool touchscreenOff: false
  readonly property bool anyHw: hwLaptop || hwTouchpad || hwTouchscreen

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
    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
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

  // ---- top asymmetrical row: dominant Brightness hero (~64%) + offset Night Light card (~36%) ----
  readonly property real leftW: Math.round((width - 2 * pad - Theme.s12) * 0.64)
  readonly property real rightW: (width - 2 * pad - Theme.s12) - leftW

  Row {
    width: parent.width; spacing: Theme.s12

    // Brightness hero card
    Rectangle {
      width: root.leftW; height: 108; radius: Theme.tileRadius + 2; color: Theme.surface; antialiasing: true
      FocusRing { on: root.row === 0; radius: parent.radius }
      Column {
        anchors.fill: parent; anchors.margins: Theme.s16; spacing: Theme.s12
        Item {
          width: parent.width; height: 24
          Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
            Icon { name: "sun"; size: Theme.iconMd; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
            Text { textFormat: Text.PlainText; text: "Brightness"; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong; anchors.verticalCenter: parent.verticalCenter }
          }
          Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
            text: Brightness.available ? (Math.round(Brightness.level * 100) + "%") : "N/A"
            color: Brightness.available ? Theme.text : Theme.textMuted; font.pixelSize: 16; font.weight: Theme.weightStrong
          }
        }
        PillSlider {
          visible: Brightness.available
          width: parent.width; icon: "sun"; value: Brightness.level
          selected: root.row === 0
          onMoved: function (v) { root.row = 0; Brightness.set(v) }
        }
        Text {
          visible: !Brightness.available; textFormat: Text.PlainText
          text: "No controllable backlight"; color: Theme.textMuted; font.pixelSize: Theme.typeBody
        }
      }
    }

    // Offset Night Light card
    Rectangle {
      id: nightCard
      width: root.rightW; height: 108; radius: Theme.tileRadius + 2; antialiasing: true
      readonly property color baseFill: Indicators.nightLight ? Theme.accentFill : Theme.surface
      color: nightArea.pressed ? Qt.lighter(baseFill, 1.16) : (nightArea.containsMouse ? Qt.lighter(baseFill, 1.08) : baseFill)
      Behavior on color { ColorAnimation { duration: 150 } }
      FocusRing { on: root.row === 1; radius: parent.radius }
      Column {
        anchors.fill: parent; anchors.margins: Theme.s16; spacing: Theme.s8
        Rectangle {
          width: 34; height: 34; radius: 17; antialiasing: true
          color: Indicators.nightLight ? Qt.rgba(1, 1, 1, 0.16) : Theme.surfaceRaised
          Icon { anchors.centerIn: parent; name: "moon"; size: Theme.iconMd - 2; color: Indicators.nightLight ? Theme.accentText : Theme.text }
        }
        Column {
          width: parent.width; spacing: 1
          Text {
            width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: "Night light"
            color: Indicators.nightLight ? Theme.accentText : Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong
          }
          Text {
            textFormat: Text.PlainText; text: Indicators.nightLight ? "Warm · On" : "Off"
            color: Indicators.nightLight ? Theme.textOnAccentMuted : Theme.textMuted; font.pixelSize: Theme.typeLabel
          }
        }
      }
      MouseArea {
        id: nightArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { root.row = 1; Indicators.toggleNightLight() }
      }
    }
  }

  // ---- Text size stepper bar ----
  Rectangle {
    width: parent.width; height: 56; radius: Theme.tileRadius; color: Theme.surface; antialiasing: true
    FocusRing { on: root.row === 2; radius: parent.radius }
    Row {
      anchors.left: parent.left; anchors.leftMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s12
      Rectangle {
        width: 34; height: 34; radius: Theme.radiusChip; color: Theme.surfaceRaised; anchors.verticalCenter: parent.verticalCenter
        Icon { anchors.centerIn: parent; name: "type"; size: Theme.iconSm; color: Theme.text }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter; spacing: 0
        Text { textFormat: Text.PlainText; text: "Text size"; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightLabel }
        Text { textFormat: Text.PlainText; text: "System & terminal UI scale"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption }
      }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Rectangle {
        antialiasing: true; width: 34; height: 34; radius: 17
        color: decArea.pressed ? Theme.accentFill : (decArea.containsMouse ? Theme.mix(Theme.surfaceRaised, Theme.text, 0.14) : Theme.surfaceRaised)
        Icon { anchors.centerIn: parent; name: "chevron-left"; size: Theme.iconSm; color: decArea.pressed ? Theme.accentText : Theme.text }
        MouseArea { id: decArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.row = 2; root.setText(root.textSize - 1) } }
      }
      Text {
        width: 48; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText; text: root.textSize + " px"; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong
      }
      Rectangle {
        antialiasing: true; width: 34; height: 34; radius: 17
        color: incArea.pressed ? Theme.accentFill : (incArea.containsMouse ? Theme.mix(Theme.surfaceRaised, Theme.text, 0.14) : Theme.surfaceRaised)
        Icon { anchors.centerIn: parent; name: "chevron-right"; size: Theme.iconSm; color: incArea.pressed ? Theme.accentText : Theme.text }
        MouseArea { id: incArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.row = 2; root.setText(root.textSize + 1) } }
      }
    }
  }

  // ---- Hardware switches (compact 2-column grid, shown only when hardware exists) ----
  Column {
    visible: root.anyHw
    width: parent.width; spacing: Theme.s8
    Text { textFormat: Text.PlainText; text: "Hardware"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
    Grid {
      width: parent.width; columns: 2; spacing: Theme.s8
      readonly property real cellW: (width - Theme.s8) / 2
      Tile {
        visible: root.hwLaptop; width: parent.cellW; height: 52
        icon: "monitor"; title: "Laptop display"; subtitle: root.laptopOff ? "Off" : "On"
        on: !root.laptopOff; selected: root.row === 3
        onClicked: { root.row = 3; root.toggleHw(3) }
      }
      Tile {
        visible: root.hwLaptop; width: parent.cellW; height: 52
        icon: "mirror"; title: "Mirror display"; subtitle: root.mirrorOn ? "On" : "Off"
        on: root.mirrorOn; selected: root.row === 4
        onClicked: { root.row = 4; root.toggleHw(4) }
      }
      Tile {
        visible: root.hwTouchpad; width: parent.cellW; height: 52
        icon: "mouse"; title: "Touchpad"; subtitle: root.touchpadOff ? "Off" : "On"
        on: !root.touchpadOff; selected: root.row === 5
        onClicked: { root.row = 5; root.toggleHw(5) }
      }
      Tile {
        visible: root.hwTouchscreen; width: parent.cellW; height: 52
        icon: "phone"; title: "Touchscreen"; subtitle: root.touchscreenOff ? "Off" : "On"
        on: !root.touchscreenOff; selected: root.row === 6
        onClicked: { root.row = 6; root.toggleHw(6) }
      }
    }
  }

  Process {
    running: true
    command: ["omarchy-display-text-size"]
    stdout: StdioCollector { onStreamFinished: { var m = /text size:\s*(\d+)/.exec(text); if (m) root.textSize = parseInt(m[1]) } }
  }
}
