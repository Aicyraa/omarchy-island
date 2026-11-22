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
  SmoothRect {                                    // fill inside the body (body spans x 2..18, y 8..16)
    x: 4.1 * root.u; y: 9.3 * root.u
    width: 12.4 * root.u * Power.level; height: 5.4 * root.u; radius: 2.7 * root.u      // a pill, to match the rounder body
    color: Power.low ? Theme.dangerInk : (Power.charging ? Theme.successInk : Theme.text)
    Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 250 } }
  }
}
