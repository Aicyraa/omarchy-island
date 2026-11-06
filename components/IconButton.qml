import QtQuick
import ".."

// Round icon button for panel headers (power toggle, rescan, scan...).
// `on` gives it the accent fill; `busy` makes the icon spin (only while true).
Item {
  id: root
  property string icon: ""
  property bool on: false
  property bool busy: false
  property bool selected: false
  signal clicked()
  implicitWidth: 36; implicitHeight: 36
  width: 36; height: 36

  Rectangle { anchors.fill: parent; radius: width / 2
    color: root.on ? Theme.accent : (area.pressed ? Theme.surfaceRaised : Theme.surface)
    border.width: root.selected ? 2 : 0; border.color: Theme.text
    Behavior on color { ColorAnimation { duration: 150 } } }
  Icon { id: ic; anchors.centerIn: parent; name: root.icon; size: Theme.iconMd; color: root.on ? Theme.accentText : Theme.text
    RotationAnimator on rotation { running: root.busy && !IslandState.reducedMotion; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
    onVisibleChanged: if (!root.busy) rotation = 0 }
  MouseArea { id: area; anchors.fill: parent; onClicked: root.clicked() }
}
