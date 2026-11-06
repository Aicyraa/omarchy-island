import QtQuick
import ".."

// The selection ring. It does not just appear: when an item gains focus the ring springs in from slightly
// larger and settles onto it, and when focus leaves it fades out, so moving the selection reads as motion.
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
  Behavior on scale { enabled: !IslandState.reducedMotion
    SpringAnimation { spring: 5.5; damping: 0.32; epsilon: 0.002 } }
}
