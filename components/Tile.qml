import QtQuick
import QtQuick.Shapes
import ".."

// A rounded toggle tile: icon, title, live subtitle, optional number badge.
// `compact: true` is the tall form used by the Power widget (big icon over a label).
// `holdMs > 0` adds click-and-hold-to-confirm with a ring filling around the icon.
//
// The number badge sits inside a SAFE INSET: at least 0.4 * the corner radius from
// the top and right edges, so it never touches the rounded corner. Badge and
// subtitle colours come from Theme roles that are guaranteed >= 4.5:1 on the tile
// surface (inactive) or on the accent fill (active).
Item {
  id: root
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property string keyHint: ""
  property bool on: false
  property bool selected: false
  property bool compact: false
  property bool danger: false
  property bool showTitle: true
  property bool iconCircle: true        // false: bare icon (more room for the label)
  property int holdMs: 0
  signal clicked()
  signal held()
  signal rightClicked()

  implicitHeight: compact ? 120 : Theme.tileHeight
  height: implicitHeight

  readonly property real r: compact ? Theme.tileRadius + 4 : height / 2
  readonly property color fill: on ? Theme.accentFill : Theme.surface
  readonly property color fg: on ? Theme.accentText : Theme.text
  readonly property color fgMuted: on ? Theme.textOnAccentMuted : Theme.textMuted
  readonly property color badgeColor: on ? Theme.textOnAccentMuted : Theme.badgeText
  readonly property real badgeInset: Math.max(Theme.s8, r * 0.4)
  property real holdProgress: 0
  // x where the title text starts in the wide form (icon slot + gaps).
  readonly property real textX: (iconCircle ? Theme.s16 + 34 + Theme.s12 : Theme.s16 + 2 + Theme.iconMd + Theme.s8)

  Rectangle {
    anchors.fill: parent; radius: root.r
    color: area.pressed ? Qt.lighter(root.fill, 1.12) : root.fill
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  FocusRing { on: root.selected; radius: root.r; ringColor: root.danger ? Theme.dangerInk : Theme.text }

  // Number badge in the safe inset.
  Text {
    visible: root.keyHint !== ""
    anchors.top: parent.top; anchors.right: parent.right
    anchors.topMargin: root.badgeInset; anchors.rightMargin: root.badgeInset
    textFormat: Text.PlainText; text: root.keyHint
    color: root.badgeColor; font.pixelSize: 11; font.weight: Theme.weightLabel
  }

  // Compact: big icon with hold ring, label underneath.
  Item {
    visible: root.compact
    anchors.fill: parent
    Item {
      id: iconBox
      width: 48; height: 48
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top; anchors.topMargin: Theme.s16
      Icon { anchors.centerIn: parent; name: root.icon; size: Theme.iconLg + 4; color: root.danger && root.selected ? Theme.dangerInk : root.fg }
      Shape {
        anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: Theme.dangerInk; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
          PathAngleArc { centerX: 24; centerY: 24; radiusX: 22; radiusY: 22; startAngle: -90; sweepAngle: root.holdProgress * 359.9 }
        }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter; anchors.top: iconBox.bottom; anchors.topMargin: Theme.s4
      textFormat: Text.PlainText; text: root.title; color: root.fg; font.pixelSize: 13; font.weight: Theme.weightLabel
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s12
      width: parent.width - Theme.s16; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
      textFormat: Text.PlainText; text: root.subtitle
      color: root.selected && root.danger ? Theme.dangerInk : root.fgMuted; font.pixelSize: 11
    }
  }

  // Wide: icon in a circle, title + subtitle.
  Row {
    visible: !root.compact
    anchors.left: parent.left; anchors.leftMargin: root.iconCircle ? Theme.s16 : Theme.s16 + 2
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.iconCircle ? Theme.s12 : Theme.s8
    Rectangle {
      visible: root.iconCircle
      width: 34; height: 34; radius: 17
      color: root.on ? Qt.rgba(0, 0, 0, 0.14) : Theme.surfaceRaised
      Icon { anchors.centerIn: parent; name: root.icon; size: Theme.iconMd - 2; color: root.fg }
    }
    Icon { visible: !root.iconCircle; anchors.verticalCenter: parent.verticalCenter; name: root.icon; size: Theme.iconMd; color: root.fg }
    Column {
      visible: root.showTitle
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      Text { width: Math.max(10, root.width - root.textX - (root.keyHint !== "" ? root.badgeInset + 14 : Theme.s16))
        elide: Text.ElideRight; textFormat: Text.PlainText; text: root.title
        color: root.fg; font.pixelSize: 13; font.weight: Theme.weightLabel }
      Text { visible: root.subtitle !== ""
        width: Math.max(10, root.width - root.textX - Theme.s16); elide: Text.ElideRight
        textFormat: Text.PlainText; text: root.subtitle; color: root.fgMuted; font.pixelSize: 11 }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: if (root.holdMs > 0) holdAnim.restart()
    onReleased: function (m) {
      if (m.button === Qt.RightButton) { root.rightClicked(); return }
      if (holdAnim.running) { holdAnim.stop(); root.holdProgress = 0; root.clicked() }
      else if (root.holdMs === 0) root.clicked()
      root.holdProgress = 0
    }
    onCanceled: { holdAnim.stop(); root.holdProgress = 0 }
  }
  NumberAnimation { id: holdAnim; target: root; property: "holdProgress"; from: 0; to: 1; duration: root.holdMs
    onFinished: { root.held(); root.holdProgress = 0 } }
}
