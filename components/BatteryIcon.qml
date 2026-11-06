import QtQuick
import ".."
import "../services"

// Battery glyph on the 24-grid, sized by token. The fill WIDTH tracks the charge
// (animated); danger-coloured when low, success-coloured when charging. A small
// bolt overlays it while charging. Hidden when the machine has no battery.
Item {
  id: root
  property real size: Theme.iconMd
  implicitWidth: size; implicitHeight: size
  visible: Power.present
  readonly property real u: size / 24          // grid unit

  Icon { anchors.fill: parent; name: "battery"; size: root.size; color: Theme.text }
  Rectangle {                                    // fill inside the body (body spans x 3..18, y 8..16)
    x: 4.4 * root.u; y: 9.4 * root.u
    width: 12.2 * root.u * Power.level; height: 5.2 * root.u; radius: 1 * root.u
    color: Power.low ? Theme.dangerInk : (Power.charging ? Theme.successInk : Theme.text)
    Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 250 } }
  }
}
