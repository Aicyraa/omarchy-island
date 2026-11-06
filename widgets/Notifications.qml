import QtQuick
import ".."
import "../services"

// Notifications: recent history, Do Not Disturb, and clear.
// Keys: ↑/↓ scroll · D toggle Focus (Do Not Disturb) · C dismiss on-screen toasts · R replay history.
Item {
  id: root
  focus: true
  property string hint: "↑/↓ scroll · D focus mode · C dismiss toasts · R replay · Esc close"
  property int sel: 0
  Component.onCompleted: Indicators.refresh()

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Notifs.history.length - 1); list.positionViewAtIndex(sel, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); list.positionViewAtIndex(sel, ListView.Contain); e.accepted = true }
    else if (e.key === Qt.Key_D) { Indicators.toggleDnd(); e.accepted = true }
    else if (e.key === Qt.Key_C) { Cmd.run(["omarchy-shell", "-q", "notifications", "dismissAll"]); e.accepted = true }
    else if (e.key === Qt.Key_R) { Cmd.run(["omarchy-shell", "-q", "notifications", "showHistory"]); e.accepted = true }
  }

  Text { x: 22; y: 14; textFormat: Text.PlainText; text: "Notifications"; color: Theme.text; font.pixelSize: 15; font.bold: true }
  Tile { anchors.right: parent.right; anchors.rightMargin: 18; y: 8; width: 130; height: 36
    icon: Indicators.dnd ? "bell-off" : "bell"; title: "Focus"; subtitle: ""; on: Indicators.dnd
    onClicked: Indicators.toggleDnd() }

  ListView {
    id: list
    x: 10; y: 54; width: root.width - 20; height: root.height - 64
    clip: true; spacing: 2; model: Notifs.history
    delegate: Item {
      required property var modelData
      required property int index
      width: list.width; height: 56
      Rectangle { anchors.fill: parent; radius: 14; color: root.sel === index ? Theme.surfaceRaised : "transparent" }
      Column { x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; spacing: 1
        // Everything below comes from other apps: plain text only, never rich text.
        Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
          text: modelData.summary || modelData.app || ""; color: Theme.text; font.pixelSize: 13; font.bold: true }
        Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
          text: (modelData.app ? modelData.app + " · " : "") + (modelData.body || ""); color: Theme.textMuted; font.pixelSize: 11 } }
      Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText; text: Notifs.ago(modelData.ts); color: Theme.textMuted; font.pixelSize: 11 }
    }
  }
  Text { visible: Notifs.history.length === 0; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "All caught up"; color: Theme.textMuted; font.pixelSize: 14 }
}
