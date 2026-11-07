import QtQuick
import ".."

// A small stat tile: muted label over a value, with an optional thin gauge along the bottom (0..1; turns warning/danger
// near the top). Width is set by the user; used by the System and Power widgets.
Rectangle {
  id: t
  property string label; property string value; property real fraction: -1
  height: 50; radius: Theme.tileRadius - 4; color: Theme.surface
  Text { x: Theme.s12; y: 8; textFormat: Text.PlainText; text: t.label; color: Theme.textMuted; font.pixelSize: 11 }
  Text { x: Theme.s12; y: 25; width: parent.width - 2 * Theme.s12; elide: Text.ElideRight; textFormat: Text.PlainText
    text: t.value; color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
  Rectangle { antialiasing: true; visible: t.fraction >= 0; x: Theme.s12; width: parent.width - 2 * Theme.s12; y: parent.height - 6; height: 3; radius: 1.5
    color: Theme.mix(Theme.surface, Theme.text, 0.16)
    Rectangle { antialiasing: true; height: parent.height; radius: 1.5; width: parent.width * Math.min(1, t.fraction)
      color: t.fraction >= 0.9 ? Theme.dangerInk : (t.fraction >= 0.75 ? Theme.warningInk : Theme.accentInk) } }
}
