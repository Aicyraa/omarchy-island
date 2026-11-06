import QtQuick
import ".."
import "../services"

// Battery whose fill WIDTH tracks the charge level (animated), turning
// danger-coloured when low. Hidden entirely when the machine has no battery.
Item {
  id: root
  implicitWidth: 24
  implicitHeight: 12
  visible: Power.present

  Rectangle {                      // body outline
    x: 0; y: 0; width: 21; height: 12; radius: 3
    color: "transparent"
    border.width: 1.5
    border.color: Theme.textMuted
  }
  Rectangle {                      // terminal nub
    x: 21.5; y: 4; width: 2; height: 4; radius: 1; color: Theme.textMuted
  }
  Rectangle {                      // fill
    x: 2.5; y: 2.5
    height: 7
    radius: 1.5
    width: 16 * Power.level
    color: Power.low ? Theme.danger : (Power.charging ? Theme.success : Theme.text)
    Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 250 } }
  }
}
