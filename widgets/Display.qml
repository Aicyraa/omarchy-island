import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Display: brightness, night light, and text size. Keys: ↑/↓ move,
// ←/→ adjust, Enter toggle night light.
WidgetPanel {
  id: root
  preferredWidth: 460
  hint: "↑/↓ move · ←/→ adjust · Enter toggle · Esc close"

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

  Text { textFormat: Text.PlainText; text: "Display"; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong }
  PillSlider {
    width: parent.width; icon: "sun"; value: Brightness.level; visible: Brightness.available
    selected: root.row === 0; showValue: true
    onMoved: function (v) { root.row = 0; Brightness.set(v) }
  }
  Text { visible: !Brightness.available; textFormat: Text.PlainText
    text: "No controllable backlight"; color: Theme.textMuted; font.pixelSize: 12 }
  Tile {
    width: parent.width
    icon: "moon"; title: "Night light"; subtitle: Indicators.nightLight ? "On" : "Off"
    on: Indicators.nightLight; selected: root.row === 1
    onClicked: { root.row = 1; Indicators.toggleNightLight() }
  }
  // Text size stepper: − 12 px +
  Rectangle {
    width: parent.width; height: Theme.tileHeight; radius: height / 2; color: Theme.surface
    border.width: root.row === 2 ? 2 : 0; border.color: Theme.text
    Icon { x: Theme.s16 + 2; anchors.verticalCenter: parent.verticalCenter; name: "type"; size: Theme.iconMd }
    Text { x: Theme.s16 + 2 + Theme.iconMd + Theme.s12; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
      text: "Text size"; color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
    Row {
      anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Rectangle { width: 34; height: 34; radius: 17; color: Theme.surfaceRaised
        Icon { anchors.centerIn: parent; name: "chevron-left"; size: Theme.iconSm }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.row = 2; root.setText(root.textSize - 1) } } }
      Text { width: 44; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText; text: root.textSize + " px"; color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
      Rectangle { width: 34; height: 34; radius: 17; color: Theme.surfaceRaised
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
