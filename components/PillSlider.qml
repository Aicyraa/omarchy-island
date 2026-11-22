import QtQuick
import QtQuick.Shapes
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
  property real maxValue: 1
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

  readonly property bool boosted: root.maxValue > 1.0 && root.value > 1.005
  readonly property color fillColor: dimmed ? Theme.mix(Theme.surfaceRaised, Theme.accentFill, 0.35)
                                            : (boosted ? Theme.mix(Theme.accentFill, Theme.warning, 0.45) : Theme.accentFill)
  readonly property color iconColor: dimmed ? Theme.text : Theme.accentText

  // No outline: selection and hover only lift the track a little (the fill keeps the accent).
  SmoothRect { anchors.fill: parent; radius: height / 2
    color: root.selected ? Theme.mix(Theme.surface, Theme.text, 0.14) : (area.containsMouse && root.interactive ? Theme.mix(Theme.surface, Theme.text, 0.08) : Theme.surface)
    Behavior on color { ColorAnimation { duration: 140 } } }

  Item {
    id: fill
    // Never narrower than the icon so the icon always stays inside the fill.
    width: Math.max(root.thin ? 0 : height, root.width * Math.max(0, Math.min(1, root.value / Math.max(0.01, root.maxValue)))) + (area.pressed && !root.thin ? 6 : 0)
    height: parent.height
    Behavior on width { enabled: !area.pressed; NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

    Shape {
      anchors.fill: parent
      readonly property bool isBgSurface: true
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient {
          x1: 0; y1: 0
          x2: 0; y2: fill.height
          GradientStop { position: 0; color: Qt.lighter(root.fillColor, 1.1) }
          GradientStop { position: 1; color: root.fillColor }
        }
        PathRectangle {
          width: fill.width > 0.5 ? fill.width : 0
          height: fill.height > 0.5 ? fill.height : 0
          radius: fill.height / 2
        }
      }
    }

    Item {
      visible: !root.thin
      anchors.left: parent.left; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      width: Theme.iconMd; height: Theme.iconMd
      Loader { anchors.fill: parent; sourceComponent: root.iconItem ? root.iconItem : plainIcon }
      Component { id: plainIcon; Icon { name: root.icon; size: Theme.iconMd; color: root.iconColor } }
      SmoothRect {                              // badge, e.g. the mute mark on the icon
        visible: root.badge !== ""
        x: parent.width - 9; y: parent.height - 9; width: 12; height: 12; radius: 6; color: Theme.danger
        borderWidth: 1.5; borderColor: root.fillColor
        Icon { anchors.centerIn: parent; name: root.badge; size: 8; color: Theme.textOnDanger; strokeWidth: 3 }
      }
    }
  }

  Label {
    visible: root.showValue && !root.thin
    anchors.right: parent.right; anchors.rightMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter
    mono: true; text: Math.round(root.value * 100) + "%"
    color: root.boosted ? Theme.warningInk : Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel
  }

  MouseArea {
    id: area
    enabled: root.interactive
    anchors.fill: parent
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    function set(x) { root.moved(Math.max(0, Math.min(root.maxValue, root.maxValue * x / width))) }
    onPressed: function (m) { set(m.x) }
    onPositionChanged: function (m) { if (pressed) set(m.x) }
    onWheel: function (w) { root.moved(Math.max(0, Math.min(root.maxValue, root.value + (w.angleDelta.y > 0 ? root.step : -root.step)))) }
  }
}
