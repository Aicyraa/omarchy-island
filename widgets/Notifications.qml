import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."
import "../services"

// Notifications: recent history, Focus (Do Not Disturb), clear-all, and per-item remove.
// No bottom dividers between items; clean soft card hierarchy with top-right removal actions.
// Keys: ↑/↓ select · Delete/Backspace remove selected · D focus mode · C clear all · Esc close.
WidgetPanel {
  id: root
  preferredWidth: 500
  hint: "↑/↓ select · Del remove · D focus · C clear all · Esc close"
  property int sel: 0
  readonly property int count: Notifs.history.length
  Component.onCompleted: Indicators.refresh()

  function removeAt(idx) {
    var item = Notifs.history[idx]
    if (!item) return
    Notifs.removeItem(item.key)
    if (sel >= Notifs.history.length) sel = Math.max(0, Notifs.history.length - 1)
  }

  function clearEverything() {
    Notifs.clearAll()
    IslandState.clearNotifs()
    sel = 0
  }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, Notifs.history.length - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_D) { Indicators.toggleDnd(); e.accepted = true }
    else if (e.key === Qt.Key_C) { clearEverything(); e.accepted = true }
    else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) { removeAt(sel); e.accepted = true }
  }

  // Header: dominant title + count badge on left; Clear all + Focus controls on top-right.
  Item {
    width: parent.width; height: 38
    Row {
      anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Text {
        textFormat: Text.PlainText; text: "Notifications"; color: Theme.text
        font.pixelSize: 16; font.weight: Theme.weightStrong; anchors.verticalCenter: parent.verticalCenter
      }
      Rectangle {
        visible: root.count > 0; height: 20; width: Math.max(22, countTxt.implicitWidth + 12); radius: 10
        color: Theme.surfaceRaised; anchors.verticalCenter: parent.verticalCenter
        Text {
          id: countTxt; anchors.centerIn: parent; textFormat: Text.PlainText; text: String(root.count)
          color: Theme.textMuted; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel
        }
      }
    }
    Row {
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Rectangle {
        height: 30; width: focusRow.implicitWidth + Theme.s12 * 2; radius: 15
        color: Indicators.dnd ? (focusArea.containsMouse ? Qt.lighter(Theme.accentFill, 1.08) : Theme.accentFill)
          : (focusArea.containsMouse ? Theme.mix(Theme.surface, Theme.text, 0.14) : Theme.surface)
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
          id: focusRow; anchors.centerIn: parent; spacing: 6
          Icon { name: Indicators.dnd ? "bell-off" : "bell"; size: Theme.iconSm; color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter }
          Text {
            textFormat: Text.PlainText; text: Indicators.dnd ? "Focus on" : "Focus"; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
            color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter
          }
        }
        MouseArea { id: focusArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Indicators.toggleDnd() }
      }
      Rectangle {
        visible: root.count > 0; height: 30; width: clearRow.implicitWidth + Theme.s12 * 2; radius: 15
        color: clearArea.pressed ? Theme.danger : (clearArea.containsMouse ? Theme.mix(Theme.surface, Theme.danger, 0.25) : Theme.surface)
        Behavior on color { ColorAnimation { duration: 130 } }
        Row {
          id: clearRow; anchors.centerIn: parent; spacing: 5
          Icon { name: "trash"; size: Theme.iconSm - 2; color: clearArea.pressed ? Theme.textOnDanger : (clearArea.containsMouse ? Theme.dangerInk : Theme.textMuted); anchors.verticalCenter: parent.verticalCenter }
          Text {
            textFormat: Text.PlainText; text: "Clear"; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
            color: clearArea.pressed ? Theme.textOnDanger : (clearArea.containsMouse ? Theme.dangerInk : Theme.textMuted); anchors.verticalCenter: parent.verticalCenter
          }
        }
        MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearEverything() }
      }
    }
  }

  // Notification list: soft spacing, zero bottom lines, top-right per-item remove button on hover/selection.
  Column {
    visible: root.count > 0
    width: parent.width - Theme.s12; spacing: Theme.s8
    Repeater {
      model: Notifs.history
      delegate: Item {
        id: card
        required property var modelData
        required property int index
        width: parent.width
        height: Math.max(62, textCol.implicitHeight + 2 * Theme.s12)
        readonly property bool selected: root.sel === index
        readonly property bool showRemove: cardHover.hovered || selected
        readonly property string preview: Notifs.previewOf(modelData)
        readonly property string iconName: Notifs.iconNameOf(modelData)
        onSelectedChanged: if (selected) root.reveal(this)
        FocusTarget { selected: card.selected; target: card }

        HoverHandler { id: cardHover }

        Rectangle {
          antialiasing: true
          anchors.fill: parent
          anchors.leftMargin: -Theme.s4; anchors.rightMargin: -Theme.s4
          radius: Theme.tileRadius
          color: cardHover.hovered && !card.selected ? Theme.mix(Theme.surface, Theme.text, 0.06) : Theme.surface
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        NotifThumb {
          id: thumb
          x: Theme.s8; anchors.verticalCenter: parent.verticalCenter
          size: 42; badge: true; preview: card.preview; iconName: card.iconName
        }

        Column {
          id: textCol
          anchors.left: thumb.right; anchors.leftMargin: Theme.s12
          anchors.right: parent.right; anchors.rightMargin: Theme.s8
          anchors.verticalCenter: parent.verticalCenter; spacing: 3
          Item {
            width: parent.width; height: 18
            Text {
              anchors.left: parent.left; anchors.right: rightMeta.left; anchors.rightMargin: Theme.s8
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight; textFormat: Text.PlainText; text: card.modelData.app || "Notification"
              color: Theme.accentInk; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel; font.letterSpacing: 0.3
            }
            Row {
              id: rightMeta
              anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
              Text {
                anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
                text: Notifs.ago(card.modelData.ts); color: Theme.textMuted; font.pixelSize: Theme.typeCaption
              }
              Rectangle {
                id: rmBtn
                visible: opacity > 0.01
                opacity: card.showRemove ? 1 : 0
                scale: card.showRemove ? 1 : 0.85
                Behavior on opacity { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                width: 20; height: 20; radius: 10; antialiasing: true
                color: rmArea.pressed ? Theme.danger : (rmArea.containsMouse ? Theme.mix(Theme.surfaceRaised, Theme.danger, 0.35) : Theme.surfaceRaised)
                Behavior on color { ColorAnimation { duration: 110 } }
                Icon {
                  anchors.centerIn: parent; name: "x"; size: 11
                  color: rmArea.pressed ? Theme.textOnDanger : (rmArea.containsMouse ? Theme.dangerInk : Theme.textMuted)
                }
                MouseArea {
                  id: rmArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: function (m) { m.accepted = true; root.removeAt(card.index) }
                }
              }
            }
          }
          Text {
            width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
            text: card.modelData.summary || card.modelData.app || ""
            color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong; font.letterSpacing: 0.1
          }
          Text {
            visible: text !== ""; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText
            text: card.modelData.body || ""; color: Theme.textMuted; font.pixelSize: Theme.typeBody; lineHeight: 1.15
          }
        }

        MouseArea {
          z: -1; anchors.fill: parent; anchors.leftMargin: -Theme.s4; anchors.rightMargin: -Theme.s4
          cursorShape: Qt.PointingHandCursor; onClicked: root.sel = card.index
        }
      }
    }
  }

  // Empty state: centered pill emblem + clear copy.
  Item {
    visible: root.count === 0
    width: parent.width; height: 128
    Column {
      anchors.centerIn: parent; spacing: Theme.s8
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 52; height: 52; radius: 26; color: Theme.surface
        Icon { anchors.centerIn: parent; name: Indicators.dnd ? "bell-off" : "bell"; size: Theme.iconMd; color: Theme.textMuted }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText
        text: "All caught up"; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText
        text: Indicators.dnd ? "Focus is on — new notifications stay quiet" : "Nothing new right now"
        color: Theme.textMuted; font.pixelSize: Theme.typeBody
      }
    }
  }
}
