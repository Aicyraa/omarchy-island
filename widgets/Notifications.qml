import QtQuick
import ".."
import "../services"

// Notifications: recent history, the Focus (Do Not Disturb) button, dismiss, replay.
// Keys: ↑/↓ scroll · D focus mode · C dismiss toasts · R replay history.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "↑/↓ select · D focus mode · C dismiss toasts · R replay · Esc close"
  property int sel: 0
  Component.onCompleted: Indicators.refresh()

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Notifs.history.length - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_D) { Indicators.toggleDnd(); e.accepted = true }
    else if (e.key === Qt.Key_C) { Cmd.run(["omarchy-shell", "-q", "notifications", "dismissAll"]); e.accepted = true }
    else if (e.key === Qt.Key_R) { Cmd.run(["omarchy-shell", "-q", "notifications", "showHistory"]); e.accepted = true }
  }

  // Header: title and a Focus button that shows its state, on one centre line.
  Item { width: parent.width; height: 36
    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Notifications"; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong }
    Rectangle {
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      height: 32; width: focusRow.implicitWidth + Theme.s16 * 2; radius: 16
      color: Indicators.dnd ? Theme.accentFill : Theme.surface
      Behavior on color { ColorAnimation { duration: 150 } }
      Row { id: focusRow; anchors.centerIn: parent; spacing: Theme.s8
        Icon { name: Indicators.dnd ? "bell-off" : "bell"; size: Theme.iconSm; color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Text { textFormat: Text.PlainText; text: Indicators.dnd ? "Focus on" : "Focus off"; font.pixelSize: 12; font.weight: Theme.weightLabel
          color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
      MouseArea { anchors.fill: parent; onClicked: Indicators.toggleDnd() }
    }
  }

  Column {
    visible: Notifs.history.length > 0
    width: parent.width; spacing: Theme.rowGap
    Repeater {
      model: Notifs.history
      delegate: ListRow {
        required property var modelData
        required property int index
        width: parent.width
        icon: "bell"
        title: modelData.summary || modelData.app || ""
        // App name, then " · body" ONLY when there is a body (no dangling separator).
        subtitle: (modelData.app || "") + (modelData.body ? ((modelData.app ? " · " : "") + modelData.body) : "")
        trailing: Notifs.ago(modelData.ts)
        selected: root.sel === index
        onSelectedChanged: if (selected) root.reveal(this)
        onClicked: root.sel = index
      }
    }
  }
  Text { visible: Notifs.history.length === 0; textFormat: Text.PlainText
    text: "All caught up"; color: Theme.textMuted; font.pixelSize: 14 }
}
