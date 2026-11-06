import QtQuick
import ".."
import "../services"

// Audio: output and input, each a slider plus a device list.
// Keys: Tab switch Output/Input, ↑/↓ move (slider row first), ←/→ adjust the
// slider, Enter sets the default device (or mutes on the slider row), M mute.
Item {
  id: root
  focus: true
  property string hint: "Tab output/input · ↑/↓ move · ←/→ adjust · Enter select · M mute · Esc close"
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

  component Side: Item {
    id: side
    required property bool isInput
    readonly property bool mine: root.inputSide === isInput
    readonly property var devs: isInput ? Audio.sources : Audio.sinks
    readonly property var current: isInput ? Audio.source : Audio.sink
    property real vol: isInput ? Audio.micVolume : Audio.volume
    property bool muted: isInput ? Audio.micMuted : Audio.muted
    width: (root.width - 18 * 2 - 16) / 2; height: root.height - 24

    Text { y: 0; textFormat: Text.PlainText; text: side.isInput ? "Input" : "Output"
      color: side.mine ? Theme.text : Theme.textMuted; font.pixelSize: 14; font.bold: true }
    PillSlider {
      y: 26; width: parent.width
      icon: side.isInput ? (side.muted ? "mic-off" : "mic") : "volume"
      iconItem: side.isInput ? null : volIcon
      Component { id: volIcon; VolumeIcon { level: side.vol; muted: side.muted; size: 20; color: Theme.accentText } }
      value: side.muted ? 0 : side.vol
      selected: side.mine && root.row === 0
      onMoved: function (v) { root.inputSide = side.isInput; root.row = 0
        side.isInput ? Audio.setMicVolume(v) : Audio.setVolume(v) }
    }
    ListView {
      y: 84; width: parent.width; height: parent.height - 84
      clip: true; spacing: 2; model: side.devs
      delegate: ListItem {
        required property var modelData
        required property int index
        width: parent ? parent.width : 0
        icon: side.isInput ? "mic" : (modelData.name && modelData.name.indexOf("bluez") >= 0 ? "headphones" : "volume")
        title: Audio.label(modelData)
        active: side.current !== null && side.current !== undefined && modelData.id === side.current.id
        selected: side.mine && root.row === index + 1
        onClicked: { root.inputSide = side.isInput; root.row = index + 1
          side.isInput ? Audio.setDefaultSource(modelData) : Audio.setDefaultSink(modelData) }
      }
    }
    Text { visible: side.devs.length === 0; y: 100; textFormat: Text.PlainText
      text: side.isInput ? "No input devices" : "No output devices"; color: Theme.textMuted; font.pixelSize: 12 }
  }

  Row { x: 18; y: 14; spacing: 16
    Side { isInput: false }
    Side { isInput: true }
  }
}
