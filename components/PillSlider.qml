import QtQuick
import ".."

// A large pill slider with the icon INSIDE the filled track (Android style).
// value is 0..1. Emits moved(v) while dragging; the owner writes the value back.
// The fill's leading edge stretches a little while dragged ("thumb stretch").
Item {
  id: root
  property string icon: ""
  property real value: 0
  property real step: 0.05
  property bool selected: false
  property Component iconItem: null     // optional custom icon (e.g. the animated VolumeIcon)
  signal moved(real v)
  implicitHeight: 44

  Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.surface
    border.width: root.selected ? 2 : 0; border.color: Theme.text }

  Rectangle {
    id: fill
    // Never narrower than the icon so it always stays inside the fill.
    width: Math.max(height, root.width * root.value) + (area.pressed ? 6 : 0)
    height: parent.height; radius: height / 2
    color: Theme.accent
    Behavior on width { enabled: !area.pressed; NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
    Loader {
      anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
      sourceComponent: root.iconItem ? root.iconItem : plainIcon
    }
    Component { id: plainIcon; Icon { name: root.icon; size: 20; color: Theme.accentText } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    function set(x) { root.moved(Math.max(0, Math.min(1, x / width))) }
    onPressed: function (m) { set(m.x) }
    onPositionChanged: function (m) { if (pressed) set(m.x) }
    onWheel: function (w) { root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? root.step : -root.step)))) }
  }
}
