import QtQuick
import Quickshell.Services.SystemTray
import ".."
import "../services"

// Tray: status icons from apps (StatusNotifierItem) as a grid. With no icons it is
// a small content-sized toast, not a full panel.
// Left click activates; right click sends the app's secondary action (many apps use
// it for the context menu). Keys: arrows select, Enter activate, M secondary.
WidgetPanel {
  id: root
  readonly property var entries: SystemTray.items.values
  compact: entries.length === 0
  preferredWidth: entries.length === 0 ? 200 : 460
  hint: "arrows select · Enter activate · M secondary · Esc close"
  property int sel: 0
  readonly property int cols: 6

  Keys.onPressed: function (e) {
    var n = entries.length; if (n === 0) return
    if (e.key === Qt.Key_Right) { sel = Math.min(sel + 1, n - 1); e.accepted = true }
    else if (e.key === Qt.Key_Left) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Down) { sel = Math.min(sel + cols, n - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - cols, 0); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { entries[sel].activate(); e.accepted = true }
    else if (e.key === Qt.Key_M) { entries[sel].secondaryActivate(); e.accepted = true }
  }

  Text { visible: root.entries.length === 0; width: parent.width; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText
    text: "No tray icons"; color: Theme.textMuted; font.pixelSize: 13 }
  Text { visible: root.entries.length > 0; textFormat: Text.PlainText; text: "Tray"; color: Theme.text; font.pixelSize: 15; font.bold: true }
  Grid {
    visible: root.entries.length > 0
    columns: root.cols; spacing: Theme.s8
    Repeater {
      model: root.entries
      delegate: Item {
        required property var modelData
        required property int index
        width: 56; height: 56
        Rectangle { anchors.fill: parent; radius: Theme.tileRadius; color: Theme.surface
          border.width: root.sel === index ? 2 : 0; border.color: Theme.text }
        Image { anchors.centerIn: parent; width: 28; height: 28; source: modelData.icon; sourceSize: Qt.size(56, 56); asynchronous: true }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: function (m) { root.sel = index; if (m.button === Qt.RightButton) modelData.secondaryActivate(); else modelData.activate() } }
      }
    }
  }
}
