import QtQuick
import ".."

// A small stat tile: muted label over a crisp value, with an optional thin gauge along
// the bottom (0..1; turns warning/danger near the top). Width is set by the caller.
Item {
  id: t
  property string label
  property string value
  property real fraction: -1
  property bool monoValue: false
  height: 54
  SmoothRect { anchors.fill: parent; radius: Theme.tileRadius; color: Theme.surface }
  Label { x: Theme.s12; y: 9; text: t.label; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
  Label {
    x: Theme.s12; y: 26; width: parent.width - 2 * Theme.s12; elide: Text.ElideRight
    mono: t.monoValue
    text: t.value; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightLabel
  }
  SmoothRect {
    visible: t.fraction >= 0
    x: Theme.s12; width: parent.width - 2 * Theme.s12; y: parent.height - 7; height: 3; radius: 1.5
    color: Theme.mix(Theme.surface, Theme.text, 0.16)
    SmoothRect {
      height: parent.height; radius: 1.5
      width: parent.width * Math.max(0, Math.min(1, t.fraction))
      color: t.fraction >= 0.9 ? Theme.dangerInk : (t.fraction >= 0.75 ? Theme.warningInk : Theme.accentInk)
    }
  }
}
