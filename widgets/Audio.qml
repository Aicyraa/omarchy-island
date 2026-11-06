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

  component Side: Column {
    id: side
    required property bool isInput
    readonly property bool mine: root.inputSide === isInput
    readonly property var devs: isInput ? Audio.sources : Audio.sinks
    readonly property var current: isInput ? Audio.source : Audio.sink
    readonly property real vol: isInput ? Audio.micVolume : Audio.volume
    readonly property bool muted: isInput ? Audio.micMuted : Audio.muted
    width: (parent.width - Theme.s16) / 2
    spacing: Theme.sectionGap

    Text { textFormat: Text.PlainText; text: side.isInput ? "Input" : "Output"
      color: side.mine ? Theme.text : Theme.textMuted; font.pixelSize: 14; font.weight: Theme.weightLabel }
    PillSlider {
      width: parent.width; showValue: true
      icon: side.isInput ? (side.muted ? "mic-off" : "mic") : "volume"
      iconItem: side.isInput ? null : volIcon
      Component { id: volIcon; VolumeIcon { level: side.vol; muted: side.muted; size: Theme.iconMd; color: Theme.accentText } }
      value: side.vol                       // the level stays visible even when muted
      dimmed: side.muted; badge: side.muted ? "x" : ""
      selected: side.mine && root.row === 0
      onMoved: function (v) { root.inputSide = side.isInput; root.row = 0
        side.isInput ? Audio.setMicVolume(v) : Audio.setVolume(v) }
    }
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
          subtitle: active ? "Default" : ""
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

  // Both columns start at the same y, so their headers and sliders share a baseline.
  Row {
    width: parent.width; spacing: Theme.s16
    Side { isInput: false }
    Side { isInput: true }
  }
}
