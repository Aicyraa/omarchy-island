import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."
import "../services"

// Notifications: recent history, the Focus (Do Not Disturb) button, dismiss, replay.
// Each notification has a preview thumbnail instead of a bell: the IMAGE it is about when there is one (a screenshot's
// file, found in the notification's open/edit action), else the app's icon from the icon theme or its desktop entry.
// Nothing is copied or cached on disk: images are read from where they already are and decoded small, in memory.
// Keys: ↑/↓ scroll · D focus mode · C dismiss toasts · R replay history.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "↑/↓ select · D focus mode · C dismiss toasts · R replay · Esc close"
  property int sel: 0
  readonly property int count: Notifs.history.length
  Component.onCompleted: Indicators.refresh()

  // The picture helpers (previewOf, iconNameOf) live in Notifs, shared with the toast.

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Notifs.history.length - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_D) { Indicators.toggleDnd(); e.accepted = true }
    else if (e.key === Qt.Key_C) { Cmd.run(["omarchy-shell", "-q", "notifications", "dismissAll"]); IslandState.clearNotifs(); e.accepted = true }
    else if (e.key === Qt.Key_R) { Cmd.run(["omarchy-shell", "-q", "notifications", "showHistory"]); e.accepted = true }
  }

  // Header: the title and how many are recent, with the Focus button on the right.
  Item { width: parent.width; height: 40
    Row { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Text { textFormat: Text.PlainText; text: "Notifications"; color: Theme.text
        font.pixelSize: 15; font.weight: Theme.weightStrong; anchors.verticalCenter: parent.verticalCenter }
      Text { visible: root.count > 0; textFormat: Text.PlainText; text: root.count
        color: Theme.textMuted; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter }
    }
    Rectangle {
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      height: 30; width: focusRow.implicitWidth + Theme.s16 * 2; radius: 15
      color: Indicators.dnd ? Theme.accentFill : Theme.surface
      Behavior on color { ColorAnimation { duration: 150 } }
      Row { id: focusRow; anchors.centerIn: parent; spacing: Theme.s8
        Icon { name: Indicators.dnd ? "bell-off" : "bell"; size: Theme.iconSm; color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Text { textFormat: Text.PlainText; text: Indicators.dnd ? "Focus on" : "Focus off"; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel
          color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
      MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Indicators.toggleDnd() }
    }
  }

  Column {
    visible: root.count > 0
    width: parent.width; spacing: 0
    Repeater {
      model: Notifs.history
      delegate: Item {
        id: card
        required property var modelData
        required property int index
        width: parent.width
        height: Math.max(60, textCol.implicitHeight + 2 * Theme.s12)
        readonly property bool selected: root.sel === index
        readonly property string preview: Notifs.previewOf(modelData)
        readonly property string iconName: Notifs.iconNameOf(modelData)
        onSelectedChanged: if (selected) root.reveal(this)
        FocusTarget { selected: card.selected; target: card }
        Rectangle { antialiasing: true; anchors.fill: parent; anchors.leftMargin: -Theme.s8; anchors.rightMargin: -Theme.s8; radius: Theme.tileRadius
          color: Theme.text; opacity: area.containsMouse && !card.selected ? 0.07 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } }

        // thumbnail: the notification's image (with the app chip), else the app icon, else a bell
        NotifThumb {
          id: thumb
          x: 0; anchors.verticalCenter: parent.verticalCenter
          size: 44; badge: true; preview: card.preview; iconName: card.iconName
        }

        Column {
          id: textCol
          anchors.left: thumb.right; anchors.leftMargin: Theme.s12; anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter; spacing: 3
          Item { width: parent.width; height: 14
            Text { anchors.left: parent.left; anchors.right: when.left; anchors.rightMargin: Theme.s8
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight; textFormat: Text.PlainText; text: card.modelData.app || ""
              color: Theme.accentInk; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel; font.letterSpacing: 0.3 }
            Text { id: when; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
              text: Notifs.ago(card.modelData.ts); color: Theme.textMuted; font.pixelSize: Theme.typeLabel } }
          Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
            text: card.modelData.summary || card.modelData.app || ""
            color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong; font.letterSpacing: 0.1 }
          Text { visible: text !== ""; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText
            text: card.modelData.body || ""; color: Theme.textMuted; font.pixelSize: Theme.typeBody; lineHeight: 1.1 }
        }

        // hairline between rows, not after the last one
        Rectangle { visible: card.index < root.count - 1
          anchors.bottom: parent.bottom; anchors.left: textCol.left; anchors.right: parent.right
          height: 1; color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07) }

        MouseArea { id: area; anchors.fill: parent; anchors.leftMargin: -Theme.s8; anchors.rightMargin: -Theme.s8
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sel = card.index }
      }
    }
  }

  // Empty state: a soft chip with the bell, and two lines of text, centred in the panel.
  Item {
    visible: root.count === 0
    width: parent.width; height: 120
    Column {
      anchors.centerIn: parent; spacing: Theme.s8
      Rectangle { anchors.horizontalCenter: parent.horizontalCenter
        width: 52; height: 52; radius: 26; color: Theme.surface
        Icon { anchors.centerIn: parent; name: "bell"; size: Theme.iconMd; color: Theme.textMuted }
      }
      Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText
        text: "All caught up"; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong }
      Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText
        text: Indicators.dnd ? "Focus is on: new ones stay quiet" : "Nothing new right now"
        color: Theme.textMuted; font.pixelSize: Theme.typeBody }
    }
  }
}
