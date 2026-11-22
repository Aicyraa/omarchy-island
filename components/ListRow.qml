import QtQuick
import ".."

// One list row, the same everywhere. Fixed height (Theme.rowHeight), a leading
// icon, title, subtitle, and a trailing area (text, optional icon, optional check).
//
// Highlights stay strictly inside the row box [0, width] (preserving uniform 16 px
// outer padding on all sides), with row content inset cleanly by Theme.s12 inside.
// Give every row in a list a subtitle (or none of them) so row heights match.
Item {
  id: root
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property string trailing: ""        // right-aligned text, e.g. "78%"
  property string trailingIcon: ""    // optional icon left of the trailing text (e.g. "lock-small")
  property string hoverActionIcon: ""
  property bool selected: false
  property bool active: false         // accent treatment + check mark
  property bool pending: false        // dimmed with an ellipsis while an action is in flight
  property Component leading: null    // optional custom leading item replacing the icon
  signal clicked()
  signal hoverActionClicked()

  implicitHeight: Theme.rowHeight
  height: Theme.rowHeight

  // The selected-row highlight is the panel's shared sliding one (FocusTarget). Only the "active" tint is drawn here.
  FocusTarget { selected: root.selected; target: root }
  SmoothRect {
    anchors.fill: parent
    radius: Theme.tileRadius
    color: root.active && !root.selected ? Qt.rgba(Theme.accentFill.r, Theme.accentFill.g, Theme.accentFill.b, 0.14) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Loader { id: lead; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter
    sourceComponent: root.leading ? root.leading : defaultLead }
  Component { id: defaultLead
    // The icon sits in a soft rounded chip, tinted with the accent (a little more when the row is active).
    Item { width: Theme.rowIcon + 8; height: Theme.rowIcon + 8
      SmoothRect { anchors.fill: parent; radius: Theme.radiusChip
        color: root.active ? Qt.rgba(Theme.accentFill.r, Theme.accentFill.g, Theme.accentFill.b, 0.24) : Theme.mix(Theme.surface, Theme.accentFill, 0.12) }
      Icon { anchors.centerIn: parent; name: root.icon; size: Theme.rowIcon; color: root.active ? Theme.accentInk : Theme.text; opacity: root.pending ? 0.5 : 1 } } }

  readonly property bool actionShown: root.hoverActionIcon !== "" && (rowHover.hovered || root.selected)

  HoverHandler { id: rowHover }

  Column {
    anchors.left: parent.left; anchors.leftMargin: Theme.s12 + Theme.rowIcon + 8 + Theme.s12
    anchors.right: trail.left; anchors.rightMargin: Theme.s8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1
    Label { width: parent.width; elide: Text.ElideRight
      text: root.title; color: Theme.text; font.pixelSize: Theme.rowTitle; font.letterSpacing: Theme.rowLetter; font.weight: root.active ? Theme.weightLabel : Font.Normal; opacity: root.pending ? 0.6 : 1 }
    Label { width: parent.width; elide: Text.ElideRight
      visible: root.subtitle !== ""; text: root.subtitle; color: root.active ? Theme.accentInk : Theme.textMuted; font.pixelSize: Theme.rowSub }
  }

  Row {
    id: trail
    anchors.right: parent.right
    anchors.rightMargin: root.actionShown ? (Theme.s12 + 30 + Theme.s8) : Theme.s12
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.s8
    Behavior on anchors.rightMargin { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Icon { visible: root.trailingIcon !== ""; name: root.trailingIcon; size: Theme.iconSm; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
    Label { visible: root.trailing !== ""; mono: true; text: root.trailing; color: Theme.textMuted; font.pixelSize: Theme.rowTrail
      anchors.verticalCenter: parent.verticalCenter }
    Icon { visible: root.active && !root.actionShown; name: "check"; size: Theme.iconSm; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
  }

  // Hover: a faint highlight (the selected row has the panel's sliding one instead).
  SmoothRect { anchors.fill: parent; radius: Theme.tileRadius
    color: Theme.text; opacity: rowHover.hovered && !root.selected ? 0.07 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } } }
  MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
  Item {
    id: hoverActionBtn
    visible: opacity > 0.01
    opacity: root.actionShown ? 1 : 0
    scale: root.actionShown ? 1 : 0.85
    Behavior on opacity { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
    width: 30; height: 30
    SmoothRect {
      anchors.fill: parent; radius: 15
      color: actionArea.pressed ? Theme.danger : (actionArea.containsMouse ? Theme.mix(Theme.surfaceRaised, Theme.danger, 0.35) : Theme.surfaceRaised)
      Behavior on color { ColorAnimation { duration: 120 } }
    }
    Icon { anchors.centerIn: parent; name: root.hoverActionIcon; size: Theme.iconSm - 2
      color: actionArea.pressed ? Theme.textOnDanger : (actionArea.containsMouse ? Theme.dangerInk : Theme.text) }
    MouseArea { id: actionArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: function (mouse) { mouse.accepted = true; root.hoverActionClicked() } }
  }
}
