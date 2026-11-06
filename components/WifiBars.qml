import QtQuick
import ".."
import "../services"

// Four signal bars that FILL with signal strength: each bar's fill height is
// animated, so the icon shows meaning (strength) rather than a static glyph.
Item {
  id: root
  implicitWidth: 16
  implicitHeight: 12
  visible: Net.hasWifi

  Row {
    anchors.bottom: parent.bottom
    spacing: 2
    Repeater {
      model: 4
      delegate: Item {
        required property int index
        width: 3
        height: 4 + index * 2.6
        // This bar is "on" when the signal reaches its quarter.
        readonly property bool on: Net.connected && Net.strength > index / 4 + 0.05
        Rectangle { anchors.fill: parent; radius: 1; color: Theme.textMuted; opacity: 0.35 }
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: parent.on ? parent.height : 0
          radius: 1
          color: Theme.text
          Behavior on height { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
        }
      }
    }
  }
}
