import QtQuick
import ".."
import "../services"

// Audio: Output and Input side by side, sharing one baseline. Each has a slider
// (a muted device still shows its level, dimmed, with a mute badge) and a device
// list with the active device marked by a check and bold.
// Keys: Tab switch Output/Input, ↑/↓ move (slider row first), ←/→ adjust,
// Enter select the device (or mute on the slider row), M mute.
WidgetPanel {
  id: root
  preferredWidth: 640
  hint: "Tab output/input · ↑/↓ move · ←/→ adjust · Enter select · M mute · Esc close"

  property bool inputSide: false
  property int row: 0                       // 0 = slider, 1.. = device rows
  readonly property var devices: inputSide ? Audio.sources : Audio.sinks

  function adjust(d) { if (inputSide) Audio.setMicVolume(Audio.micVolume + d); else Audio.setVolume(Audio.volume + d) }
  function mute() { if (inputSide) Audio.toggleMicMute(); else Audio.toggleMute() }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { inputSide = !inputSide; row = 0; e.accepted = true }
    else if (e.key === Qt.Key_Down) { row = Math.min(row + 1, devices.length); e.accepted = true }
    else if (e.key === Qt.Key_Up) { row = Math.max(row - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Left) { adjust(-0.05); e.accepted = true }
    else if (e.key === Qt.Key_Right) { adjust(0.05); e.accepted = true }
    else if (e.key === Qt.Key_M) { mute(); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
      if (row === 0) mute()
      else { var n = devices[row - 1]; if (n) { inputSide ? Audio.setDefaultSource(n) : Audio.setDefaultSink(n) } }
      e.accepted = true
    }
  }

  // One side (Output or Input) as a card: header (icon disc, title, mute button), the active device and level, the
  // slider, then the device list. The panel's sliding highlight runs over the rows inside the card.
  component Side: Rectangle {
    id: side
    required property bool isInput
    readonly property bool mine: root.inputSide === isInput
    readonly property var devs: isInput ? Audio.sources : Audio.sinks
    readonly property var current: isInput ? Audio.source : Audio.sink
    readonly property real vol: isInput ? Audio.micVolume : Audio.volume
    readonly property bool muted: isInput ? Audio.micMuted : Audio.muted
    width: (parent.width - root.colGap) / 2
    height: body.implicitHeight + 2 * Theme.s12
    radius: Theme.tileRadius + 2
    color: Theme.surface

    Column {
      id: body
      x: Theme.s16; y: Theme.s12; width: parent.width - 2 * Theme.s16; spacing: Theme.s12

      // header
      Item { width: parent.width; height: 36
        Rectangle { antialiasing: true; id: disc; width: 36; height: 36; radius: 18
          color: side.muted ? Theme.mix(Theme.surface, Theme.text, 0.12) : Theme.accentFill
          Behavior on color { ColorAnimation { duration: 150 } }
          Icon { anchors.centerIn: parent; name: side.isInput ? (side.muted ? "mic-off" : "mic") : "volume"; size: Theme.iconMd
            color: side.muted ? Theme.textMuted : Theme.accentText; visible: side.isInput } 
          VolumeIcon { anchors.centerIn: parent; visible: !side.isInput; level: side.vol; muted: side.muted; size: Theme.iconMd
            color: side.muted ? Theme.textMuted : Theme.accentText }
          MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.inputSide = side.isInput; root.row = 0; side.isInput ? Audio.toggleMicMute() : Audio.toggleMute() } } }
        Column { anchors.left: disc.right; anchors.leftMargin: Theme.s12; anchors.right: pct.left; anchors.rightMargin: Theme.s8; anchors.verticalCenter: parent.verticalCenter; spacing: 0
          Text { width: parent.width; textFormat: Text.PlainText; text: side.isInput ? "Input" : "Output"
            color: Theme.text; font.pixelSize: 14; font.weight: Theme.weightLabel }
          Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
            text: side.muted ? "Muted" : (side.current ? Audio.label(side.current) : "No device")
            color: side.muted ? Theme.warningInk : Theme.textMuted; font.pixelSize: 11 } }
        Text { id: pct; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
          text: Math.round(side.vol * 100) + "%"; color: side.muted ? Theme.textMuted : Theme.text; font.pixelSize: 20; font.weight: Theme.weightStrong }
      }

      PillSlider {
        width: parent.width
        icon: side.isInput ? "mic" : "volume"
        iconItem: side.isInput ? null : volIcon
        Component { id: volIcon; VolumeIcon { level: side.vol; muted: side.muted; size: Theme.iconMd; color: Theme.accentText } }
        thin: false; value: side.vol                       // the level stays visible even when muted
        dimmed: side.muted
        selected: side.mine && root.row === 0
        onMoved: function (v) { root.inputSide = side.isInput; root.row = 0
          side.isInput ? Audio.setMicVolume(v) : Audio.setVolume(v) }
      }

      Text { textFormat: Text.PlainText; text: side.isInput ? "Microphones" : "Speakers and headphones"; color: Theme.textMuted; font.pixelSize: 11; font.weight: Theme.weightLabel }
      Column {
        width: parent.width; spacing: Theme.rowGap
        Repeater {
          model: side.devs
          delegate: ListRow {
            required property var modelData
            required property int index
            width: parent.width
            icon: side.isInput ? "mic" : (modelData.name && modelData.name.indexOf("bluez") >= 0 ? "headphones" : "volume")
            title: Audio.label(modelData)
            subtitle: active ? "In use" : ""
            active: side.current !== null && side.current !== undefined && modelData.id === side.current.id
            selected: side.mine && root.row === index + 1
            onSelectedChanged: if (selected) root.reveal(this)
            onClicked: { root.inputSide = side.isInput; root.row = index + 1
              side.isInput ? Audio.setDefaultSource(modelData) : Audio.setDefaultSink(modelData) }
          }
        }
        Text { visible: side.devs.length === 0; textFormat: Text.PlainText
          text: side.isInput ? "No input devices" : "No output devices"; color: Theme.textMuted; font.pixelSize: 12 }
      }
    }
  }

  readonly property int colGap: Theme.s12
  Row {
    width: parent.width; spacing: root.colGap
    Side { isInput: false }
    Side { isInput: true }
  }

  // Restarts the PipeWire services and recovers stuck USB audio (the stock Update > Hardware > Audio action).
  Item {
    width: parent.width; height: 36
    IconButton { anchors.right: parent.right; icon: "restart"; onClicked: Cmd.run(["omarchy-restart-audio"]) }
  }
}
