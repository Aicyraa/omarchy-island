import QtQuick
import ".."

// The selection ring. When an item gains focus the ring eases in from slightly larger and fades in; when focus leaves
// it fades out. One short ease-out per property, so it lands cleanly.
Rectangle {
  id: ring
  property bool on: false
  property color ringColor: Theme.text
  anchors.fill: parent
  color: "transparent"
  border.width: 2; border.color: ringColor
  opacity: on ? 1 : 0
  scale: on ? 1 : 1.06
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140 } }
  // A short ease-out tween: no overshoot, so the ring lands on the item without wobbling.
  Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
}
