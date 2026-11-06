import QtQuick
import QtQuick.Shapes
import ".."

// A rounded toggle tile (the Android quick-settings look): icon, title and a
// live subtitle. `compact: false` is the wide horizontal form; `compact: true`
// is the tall form used by the Power widget (big icon over a label).
// `holdMs > 0` adds click-and-hold-to-confirm with a ring filling around the icon.
Item {
  id: root
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property string keyHint: ""         // shown in the corner, e.g. "1"
  property bool on: false             // filled with the accent colour
  property bool selected: false       // keyboard selection ring
  property bool compact: false
  property bool danger: false
  property int holdMs: 0
  signal clicked()
  signal held()
  signal rightClicked()

  readonly property color fill: on ? Theme.accent : Theme.surface
  readonly property color fg: on ? Theme.accentText : Theme.text
  readonly property color fgMuted: on ? Theme.accentText : Theme.textMuted
  property real holdProgress: 0

  Rectangle {
    id: body
    anchors.fill: parent
    radius: root.compact ? 22 : height / 2
    color: root.mouse.pressed ? Qt.lighter(root.fill, 1.12) : root.fill
    border.width: root.selected ? 2 : 0
    border.color: root.danger ? Theme.danger : Theme.text
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  // Keyboard hint badge
  Text {
    visible: root.keyHint !== ""
    anchors.top: parent.top; anchors.right: parent.right
    anchors.margins: root.compact ? 10 : 8
    textFormat: Text.PlainText
    text: root.keyHint
    color: root.fgMuted
    font.pixelSize: 11; font.bold: true
  }

  // Compact: icon centred with optional hold ring, label underneath.
  Item {
    visible: root.compact
    anchors.fill: parent
    Item {
      id: iconBox
      width: 48; height: 48
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top; anchors.topMargin: 18
      Icon { anchors.centerIn: parent; name: root.icon; size: 28; color: root.danger && root.selected ? Theme.danger : root.fg }
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: Theme.danger; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
          PathAngleArc { centerX: 24; centerY: 24; radiusX: 22; radiusY: 22; startAngle: -90; sweepAngle: root.holdProgress * 359.9 }
        }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: iconBox.bottom; anchors.topMargin: 6
      textFormat: Text.PlainText; text: root.title
      color: root.fg; font.pixelSize: 13; font.bold: true
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: 10
      width: parent.width - 16; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
      textFormat: Text.PlainText; text: root.subtitle
      color: root.selected && root.danger ? Theme.danger : root.fgMuted; font.pixelSize: 10
    }
  }

  // Wide: icon in a circle, title + subtitle.
  Row {
    visible: !root.compact
    anchors.left: parent.left; anchors.leftMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10
    Rectangle {
      width: 34; height: 34; radius: 17
      color: root.on ? Qt.rgba(0, 0, 0, 0.14) : Theme.surfaceRaised
      Icon { anchors.centerIn: parent; name: root.icon; size: 18; color: root.fg }
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      Text { width: root.width - 34 - 14 - 10 - 14 - (root.keyHint !== "" ? 14 : 0); elide: Text.ElideRight
        textFormat: Text.PlainText; text: root.title; color: root.fg; font.pixelSize: 13; font.bold: true }
      Text {
        visible: root.subtitle !== ""
        width: root.width - 34 - 14 - 10 - 14; elide: Text.ElideRight
        textFormat: Text.PlainText; text: root.subtitle; color: root.fgMuted; font.pixelSize: 11
      }
    }
  }

  property alias mouse: area
  MouseArea {
    id: area
    anchors.fill: parent
    onPressed: if (root.holdMs > 0) holdAnim.restart()
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onReleased: function (m) {
      if (m.button === Qt.RightButton) { root.rightClicked(); return }
      if (holdAnim.running) { holdAnim.stop(); root.holdProgress = 0; root.clicked() }
      else if (root.holdMs === 0) root.clicked()
      root.holdProgress = 0
    }
    onCanceled: { holdAnim.stop(); root.holdProgress = 0 }
  }
  NumberAnimation {
    id: holdAnim
    target: root; property: "holdProgress"; from: 0; to: 1
    duration: root.holdMs
    onFinished: { root.held(); root.holdProgress = 0 }
  }
}
