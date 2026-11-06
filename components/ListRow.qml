import QtQuick
import ".."

// One list row, the same everywhere. Fixed height (Theme.rowHeight), a leading
// icon, title, subtitle, and a trailing area (text, optional icon, optional check).
//
// The row's CONTENT sits on the panel's shared left edge (x = 0 of the column).
// Its hover/selection highlight BLEEDS outward by 8px (half the padding) on both sides, so
// the highlight stays 8px short of the pill edge while icons and text stay on the shared inset.
// Give every row in a list a subtitle (or none of them) so row heights match.
Item {
  id: root
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property string trailing: ""        // right-aligned text, e.g. "78%"
  property string trailingIcon: ""    // optional icon left of the trailing text (e.g. "lock-small")
  property bool selected: false
  property bool active: false         // accent treatment + check mark
  property bool pending: false        // dimmed with an ellipsis while an action is in flight
  property Component leading: null    // optional custom leading item replacing the icon
  signal clicked()

  implicitHeight: Theme.rowHeight
  height: Theme.rowHeight

  // Bleeding highlight.
  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -Theme.s8; anchors.rightMargin: -Theme.s8      // bleeds 8px, leaving 8px to the pill edge
    radius: Theme.tileRadius
    color: root.selected ? Theme.surfaceRaised : (root.active ? Qt.rgba(Theme.accentFill.r, Theme.accentFill.g, Theme.accentFill.b, 0.14) : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }
    scale: (root.selected || root.active) ? 1 : 0.97
    Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
  }
  // Focus marker: a vertical pill (the workspace indicator's shape) that springs open on the selected row.
  Rectangle {
    x: -Theme.s8 + 4; anchors.verticalCenter: parent.verticalCenter
    width: 3; radius: 1.5; color: Theme.accentInk
    height: root.selected ? 20 : 0
    opacity: root.selected ? 1 : 0
    Behavior on height { enabled: !IslandState.reducedMotion; SpringAnimation { spring: 4.5; damping: 0.30; epsilon: 0.3 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  Loader { id: lead; x: 0; anchors.verticalCenter: parent.verticalCenter
    sourceComponent: root.leading ? root.leading : defaultLead }
  Component { id: defaultLead; Icon { name: root.icon; size: Theme.iconMd; color: root.active ? Theme.accentInk : Theme.text; opacity: root.pending ? 0.5 : 1 } }

  Column {
    anchors.left: parent.left; anchors.leftMargin: Theme.iconMd + Theme.s12
    anchors.right: trail.left; anchors.rightMargin: Theme.s8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText    // names come from outside: untrusted
      text: root.title; color: Theme.text; font.pixelSize: 13; font.weight: root.active ? Theme.weightLabel : Font.Normal; opacity: root.pending ? 0.6 : 1 }
    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      visible: root.subtitle !== ""; text: root.subtitle; color: root.active ? Theme.accentInk : Theme.textMuted; font.pixelSize: 11 }
  }

  Row {
    id: trail
    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.s8
    Icon { visible: root.trailingIcon !== ""; name: root.trailingIcon; size: Theme.iconSm; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
    Text { visible: root.trailing !== ""; textFormat: Text.PlainText; text: root.trailing; color: Theme.textMuted; font.pixelSize: 11
      anchors.verticalCenter: parent.verticalCenter }
    Icon { visible: root.active; name: "check"; size: Theme.iconSm; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
  }

  MouseArea { anchors.fill: parent; anchors.leftMargin: -Theme.s8; anchors.rightMargin: -Theme.s8; onClicked: root.clicked() }
}
