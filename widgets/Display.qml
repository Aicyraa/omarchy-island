import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Display: brightness, night light, and text size.
// Keys: ↑/↓ move, ←/→ adjust, Enter toggle night light.
Item {
  id: root
  focus: true
  property string hint: "↑/↓ move · ←/→ adjust · Enter toggle · Esc close"
  property int row: 0                       // 0 brightness, 1 night light, 2 text size
  property int textSize: 12

  Component.onCompleted: { Brightness.refresh(); Indicators.refresh() }

  function setText(n) { textSize = Math.max(8, Math.min(24, n)); Cmd.run(["omarchy-display-text-size", String(textSize)]) }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { row = Math.min(row + 1, 2); e.accepted = true }
    else if (e.key === Qt.Key_Up) { row = Math.max(row - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
      var d = e.key === Qt.Key_Right ? 1 : -1
      if (row === 0) Brightness.set(Brightness.level + d * 0.05)
      else if (row === 2) setText(textSize + d)
      e.accepted = true
    }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (row === 1) Indicators.toggleNightLight(); e.accepted = true }
  }

  Text { x: 22; y: 16; textFormat: Text.PlainText; text: "Display"; color: Theme.text; font.pixelSize: 15; font.bold: true }

  PillSlider {
    x: 18; y: 48; width: root.width - 36
    icon: "sun"; value: Brightness.level; visible: Brightness.available
    selected: root.row === 0
    onMoved: function (v) { root.row = 0; Brightness.set(v) }
  }
  Text { visible: !Brightness.available; x: 22; y: 58; textFormat: Text.PlainText
    text: "No controllable backlight"; color: Theme.textMuted; font.pixelSize: 12 }

  Tile {
    x: 18; y: 106; width: root.width - 36; height: 56
    icon: "moon"; title: "Night light"; subtitle: Indicators.nightLight ? "On" : "Off"
    on: Indicators.nightLight; selected: root.row === 1
    onClicked: { root.row = 1; Indicators.toggleNightLight() }
  }

  // Text size stepper: − 12 px +
  Rectangle {
    x: 18; y: 172; width: root.width - 36; height: 56; radius: 28; color: Theme.surface
    border.width: root.row === 2 ? 2 : 0; border.color: Theme.text
    Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "type"; size: 20 }
    Text { x: 52; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
      text: "Text size"; color: Theme.text; font.pixelSize: 13; font.bold: true }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 8
      Rectangle { width: 34; height: 34; radius: 17; color: Theme.surfaceRaised
        Icon { anchors.centerIn: parent; name: "chevron-left"; size: 16 }
        MouseArea { anchors.fill: parent; onClicked: { root.row = 2; root.setText(root.textSize - 1) } } }
      Text { width: 44; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText; text: root.textSize + " px"; color: Theme.text; font.pixelSize: 13; font.bold: true }
      Rectangle { width: 34; height: 34; radius: 17; color: Theme.surfaceRaised
        Icon { anchors.centerIn: parent; name: "chevron-right"; size: 16 }
        MouseArea { anchors.fill: parent; onClicked: { root.row = 2; root.setText(root.textSize + 1) } } }
    }
  }

  Process {
    running: true
    command: ["omarchy-display-text-size"]
    stdout: StdioCollector { onStreamFinished: {
      var m = /text size:\s*(\d+)/.exec(text); if (m) root.textSize = parseInt(m[1])
    } }
  }
}
