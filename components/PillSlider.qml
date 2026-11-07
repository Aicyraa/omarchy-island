import QtQuick
import ".."

// The ONE slider. A thick pill track with the icon INSIDE the filled part (the
// Android quick-settings look). Used for volume, brightness, mic, the HUD, and
// (thin variant) media progress.
//
//   value      0..1
//   showValue  draws the percentage right-aligned inside the track
//   dimmed     fill drawn muted (a muted mic still shows its level)
//   badge      small icon on the leading icon (e.g. "x" for muted)
//   thin       6px progress bar, no icon
// The fill's leading edge stretches a little while dragged ("thumb stretch").
Item {
  id: root
  property string icon: ""
  property Component iconItem: null        // optional custom icon (e.g. the animated VolumeIcon)
  property real value: 0
  property real step: 0.05
  property bool selected: false
  property bool showValue: false
  property bool dimmed: false
  property bool thin: false
  property string badge: ""
  property bool interactive: true
  signal moved(real v)

  implicitHeight: thin ? 6 : Theme.sliderHeight
  height: implicitHeight

  readonly property color fillColor: dimmed ? Theme.mix(Theme.surfaceRaised, Theme.accentFill, 0.35) : Theme.accentFill
  readonly property color iconColor: dimmed ? Theme.text : Theme.accentText

  // No outline: selection and hover only lift the track a little (the fill keeps the accent).
  Rectangle { antialiasing: true; anchors.fill: parent; radius: height / 2
    color: root.selected ? Theme.mix(Theme.surface, Theme.text, 0.14) : (area.containsMouse && root.interactive ? Theme.mix(Theme.surface, Theme.text, 0.08) : Theme.surface)
    Behavior on color { ColorAnimation { duration: 140 } } }

  Rectangle {
    id: fill
    // Never narrower than the icon so the icon always stays inside the fill.
    width: Math.max(root.thin ? 0 : height, root.width * root.value) + (area.pressed && !root.thin ? 6 : 0)
    height: parent.height; radius: height / 2
    color: root.fillColor
    Behavior on width { enabled: !area.pressed; NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Item {
      visible: !root.thin
      anchors.left: parent.left; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      width: Theme.iconMd; height: Theme.iconMd
      Loader { anchors.fill: parent; sourceComponent: root.iconItem ? root.iconItem : plainIcon }
      Component { id: plainIcon; Icon { name: root.icon; size: Theme.iconMd; color: root.iconColor } }
      Rectangle {                              // badge, e.g. the mute mark on the icon
        visible: root.badge !== ""
        x: parent.width - 9; y: parent.height - 9; width: 12; height: 12; radius: 6; color: Theme.danger
        border.width: 1.5; border.color: root.fillColor
        Icon { anchors.centerIn: parent; name: root.badge; size: 8; color: Theme.textOnDanger; strokeWidth: 3 }
      }
    }
  }

  Text {
    visible: root.showValue && !root.thin
    anchors.right: parent.right; anchors.rightMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText; text: Math.round(root.value * 100) + "%"
    color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel
  }

  MouseArea {
    id: area
    enabled: root.interactive
    anchors.fill: parent
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    function set(x) { root.moved(Math.max(0, Math.min(1, x / width))) }
    onPressed: function (m) { set(m.x) }
    onPositionChanged: function (m) { if (pressed) set(m.x) }
    onWheel: function (w) { root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? root.step : -root.step)))) }
  }
}
