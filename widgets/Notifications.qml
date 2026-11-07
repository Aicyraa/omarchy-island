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
  Component.onCompleted: Indicators.refresh()

  // First absolute image path found anywhere in a notification's open/edit action (JSON text), "" if none.
  function imageIn(v) {
    if (typeof v === "string") return /^\/.*\.(png|jpe?g|webp|gif|bmp)$/i.test(v) ? v : ""
    if (Array.isArray(v)) { for (var i = 0; i < v.length; i++) { var r = imageIn(v[i]); if (r !== "") return r } return "" }
    if (v && typeof v === "object") { for (var k in v) { var q = imageIn(v[k]); if (q !== "") return q } }
    return ""
  }
  function previewOf(n) {
    try { var a = imageIn(JSON.parse(n.execArgv || "[]")); if (a !== "") return a } catch (e) {}
    try { return imageIn(JSON.parse(n.execActions || "[]")) } catch (e) { return "" }
  }
  // The app icon: the notification's own icon name, else its desktop entry's icon, else an icon named like the app.
  // Quickshell.iconPath(name, true) is "" when the theme has no such icon.
  function iconNameOf(n) {
    var app = String(n.app || "")
    var e = app !== "" ? (DesktopEntries.heuristicLookup(app) || DesktopEntries.heuristicLookup(app.toLowerCase())) : null
    var cands = [String(n.appIcon || ""), e ? String(e.icon || "") : "", app.toLowerCase(), app.toLowerCase().replace(/\s+/g, "-")]
    for (var i = 0; i < cands.length; i++) if (cands[i] !== "" && Quickshell.iconPath(cands[i], true) !== "") return cands[i]
    return ""
  }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Notifs.history.length - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_D) { Indicators.toggleDnd(); e.accepted = true }
    else if (e.key === Qt.Key_C) { Cmd.run(["omarchy-shell", "-q", "notifications", "dismissAll"]); e.accepted = true }
    else if (e.key === Qt.Key_R) { Cmd.run(["omarchy-shell", "-q", "notifications", "showHistory"]); e.accepted = true }
  }

  // Header: a Focus button that shows its state, on one centre line.
  Item { width: parent.width; height: 36
    Rectangle {
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      height: 32; width: focusRow.implicitWidth + Theme.s16 * 2; radius: 16
      color: Indicators.dnd ? Theme.accentFill : Theme.surface
      Behavior on color { ColorAnimation { duration: 150 } }
      Row { id: focusRow; anchors.centerIn: parent; spacing: Theme.s8
        Icon { name: Indicators.dnd ? "bell-off" : "bell"; size: Theme.iconSm; color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Text { textFormat: Text.PlainText; text: Indicators.dnd ? "Focus on" : "Focus off"; font.pixelSize: 12; font.weight: Theme.weightLabel
          color: Indicators.dnd ? Theme.accentText : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
      MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Indicators.toggleDnd() }
    }
  }

  Column {
    visible: Notifs.history.length > 0
    width: parent.width; spacing: Theme.rowGap
    Repeater {
      model: Notifs.history
      delegate: Item {
        id: card
        required property var modelData
        required property int index
        width: parent.width
        height: Math.max(64, textCol.implicitHeight + 2 * Theme.s12)
        readonly property bool selected: root.sel === index
        readonly property string preview: root.previewOf(modelData)
        readonly property string iconName: root.iconNameOf(modelData)
        onSelectedChanged: if (selected) root.reveal(this)
        FocusTarget { selected: card.selected; target: card }
        Rectangle { antialiasing: true; anchors.fill: parent; anchors.leftMargin: -Theme.s8; anchors.rightMargin: -Theme.s8; radius: Theme.tileRadius
          color: Theme.text; opacity: area.containsMouse && !card.selected ? 0.07 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } }

        // thumbnail: the notification's image, else the app icon, else a bell
        ClippingRectangle {
          id: thumb
          x: 0; anchors.verticalCenter: parent.verticalCenter
          width: 48; height: 48; radius: 13; color: Theme.surface
          Image { id: previewImg; anchors.fill: parent; visible: status === Image.Ready
            source: card.preview !== "" ? "file://" + card.preview : ""
            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true; mipmap: true
            sourceSize.width: 192; sourceSize.height: 192 }
          Image { anchors.centerIn: parent; width: 30; height: 30; visible: previewImg.status !== Image.Ready && card.iconName !== ""
            source: card.iconName !== "" ? "image://icon/" + card.iconName : ""
            fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; sourceSize.width: 96; sourceSize.height: 96 }
          Icon { anchors.centerIn: parent; name: "bell"; size: Theme.iconMd; color: Theme.textMuted
            visible: previewImg.status !== Image.Ready && card.iconName === "" }
        }

        Column {
          id: textCol
          anchors.left: thumb.right; anchors.leftMargin: Theme.s12; anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter; spacing: 2
          Item { width: parent.width; height: 18
            Text { anchors.left: parent.left; anchors.right: when.left; anchors.rightMargin: Theme.s8; anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight; textFormat: Text.PlainText; text: card.modelData.summary || card.modelData.app || ""
              color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
            Text { id: when; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
              text: Notifs.ago(card.modelData.ts); color: Theme.textMuted; font.pixelSize: 11 } }
          Text { visible: text !== ""; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText
            text: card.modelData.body || ""; color: Theme.textMuted; font.pixelSize: 12 }
          Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; visible: text !== ""
            text: card.modelData.app || ""; color: Theme.mix(Theme.textMuted, Theme.pill, 0.25); font.pixelSize: 10 }
        }
        MouseArea { id: area; anchors.fill: parent; anchors.leftMargin: -Theme.s8; anchors.rightMargin: -Theme.s8
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sel = card.index }
      }
    }
  }
  Text { visible: Notifs.history.length === 0; textFormat: Text.PlainText
    text: "All caught up"; color: Theme.textMuted; font.pixelSize: 14 }
}
