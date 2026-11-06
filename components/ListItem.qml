import QtQuick
import ".."

// One row in a list: icon, title, subtitle, a trailing text, and selection /
// active styling. Used by the Wi-Fi, Bluetooth and Audio widgets.
Item {
  id: root
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property string trailing: ""
  property bool selected: false
  property bool active: false         // e.g. the connected network / default device
  signal clicked()
  implicitHeight: 44

  Rectangle {
    anchors.fill: parent; radius: 14
    color: root.selected ? Theme.surfaceRaised : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }
  Icon { id: ic; x: 14; anchors.verticalCenter: parent.verticalCenter
    name: root.icon; size: 18; color: root.active ? Theme.accent : Theme.text }
  Column {
    anchors.left: ic.right; anchors.leftMargin: 12
    anchors.right: tr.left; anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText   // names come from the network: untrusted
      text: root.title; color: Theme.text; font.pixelSize: 13; font.bold: root.active }
    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      visible: root.subtitle !== ""; text: root.subtitle; color: Theme.textMuted; font.pixelSize: 11 }
  }
  Text { id: tr; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText; text: root.trailing; color: Theme.textMuted; font.pixelSize: 11 }
  MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
