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
  // A press squeezes the button a little, and it springs back.
  scale: area.pressed ? 0.94 : 1
  Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

  SmoothRect { anchors.fill: parent; radius: width / 2
    color: root.on ? (area.containsMouse ? Qt.lighter(Theme.accentFill, 1.12) : Theme.accentFill) : (area.pressed ? Theme.surfaceRaised : (area.containsMouse ? Theme.mix(Theme.surface, Theme.text, 0.12) : Theme.surface))
    Behavior on color { ColorAnimation { duration: 150 } }
    FocusRing { on: root.selected; radius: width / 2 } }
  Icon { id: ic; anchors.centerIn: parent; name: root.icon; size: Theme.iconMd; color: root.on ? Theme.accentText : Theme.text
    RotationAnimator on rotation { running: root.busy && !IslandState.reducedMotion; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
    onVisibleChanged: if (!root.busy) rotation = 0 }
  MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
