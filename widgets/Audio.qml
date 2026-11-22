import QtQuick
import ".."
import "../services"

// Audio: asymmetrical split — Output (dominant, ~56%) on the left, Input (offset, ~44%) on the right.
// Devices sit at the top of each card so switching sinks/sources is immediate, with the 0–150% PillSlider
// anchored cleanly at the bottom of each card.
// Keys: Tab switch Output/Input, ↑/↓ move (devices then slider), ←/→ adjust (0–150%), Enter select/mute, M mute.
WidgetPanel {
  id: root
  preferredWidth: 660
  hint: "Tab output/input · ↑/↓ move · ←/→ adjust · Enter select · M mute · Esc close"

  property bool inputSide: false
  property int row: 0                       // 0..devices.length-1 = device rows, devices.length = slider
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
      if (row === devices.length) mute()
      else {
        var n = devices[row]
        if (n) { inputSide ? Audio.setDefaultSource(n) : Audio.setDefaultSink(n) }
      }
      e.accepted = true
    }
  }

  component Side: SmoothRect {
    id: side
    required property bool isInput
    readonly property bool mine: root.inputSide === isInput
    readonly property var devs: isInput ? Audio.sources : Audio.sinks
    readonly property var current: isInput ? Audio.source : Audio.sink
    readonly property real vol: isInput ? Audio.micVolume : Audio.volume
    readonly property bool muted: isInput ? Audio.micMuted : Audio.muted
    readonly property bool boosted: vol > 1.005
    height: body.implicitHeight + 2 * Theme.s16
    radius: Theme.tileRadius + 2
    color: Theme.surface

    Column {
      id: body
      x: Theme.s16; y: Theme.s16; width: parent.width - 2 * Theme.s16; spacing: Theme.s12

      // Header: mute disc, Output/Input title + active device, live percentage (warning tint >100%).
      Item {
        width: parent.width; height: 38
        SmoothRect {
          id: disc; width: 38; height: 38; radius: 19
          color: side.muted ? Theme.mix(Theme.surface, Theme.text, 0.12) : Theme.accentFill
          Behavior on color { ColorAnimation { duration: 150 } }
          Icon {
            anchors.centerIn: parent; name: side.muted ? "mic-off" : "mic"; size: Theme.iconMd
            color: side.muted ? Theme.textMuted : Theme.accentText; visible: side.isInput
          }
          VolumeIcon {
            anchors.centerIn: parent; visible: !side.isInput; level: side.vol; muted: side.muted; size: Theme.iconMd
            color: side.muted ? Theme.textMuted : Theme.accentText
          }
          MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { root.inputSide = side.isInput; root.row = side.devs.length; side.isInput ? Audio.toggleMicMute() : Audio.toggleMute() }
          }
        }
        Column {
          anchors.left: disc.right; anchors.leftMargin: Theme.s12
          anchors.right: pct.left; anchors.rightMargin: Theme.s8
          anchors.verticalCenter: parent.verticalCenter; spacing: 1
          Label {
            width: parent.width; text: side.isInput ? "Input" : "Output"
            color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong
          }
          Label {
            width: parent.width; elide: Text.ElideRight
            text: side.muted ? "Muted" : (side.current ? Audio.label(side.current) : "No device")
            color: side.muted ? Theme.warningInk : Theme.textMuted; font.pixelSize: Theme.typeLabel
          }
        }
        Label {
          id: pct; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; mono: true
          text: Math.round(side.vol * 100) + "%"
          color: side.muted ? Theme.textMuted : (side.boosted ? Theme.warningInk : Theme.text)
          font.pixelSize: side.isInput ? 18 : 22; font.weight: Theme.weightStrong
        }
      }

      // Available devices first (swapped above the slider).
      Label {
        text: side.isInput ? "Microphones" : "Speakers & headphones"
        color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
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
            subtitle: active ? "In use" : ""
            active: side.current !== null && side.current !== undefined && modelData.id === side.current.id
            selected: side.mine && root.row === index
            onSelectedChanged: if (selected) root.reveal(this)
            onClicked: {
              root.inputSide = side.isInput; root.row = index
              side.isInput ? Audio.setDefaultSource(modelData) : Audio.setDefaultSink(modelData)
            }
          }
        }
        Label {
          visible: side.devs.length === 0
          text: side.isInput ? "No input devices" : "No output devices"
          color: Theme.textMuted; font.pixelSize: Theme.typeBody
        }
      }

      // Volume slider at the bottom of the card (0–150%, with 100% unity notch).
      PillSlider {
        width: parent.width
        icon: side.isInput ? (side.muted ? "mic-off" : "mic") : "volume"
        iconItem: side.isInput ? null : volIcon
        Component { id: volIcon; VolumeIcon { level: side.vol; muted: side.muted; size: Theme.iconMd; color: Theme.accentText } }
        thin: false; value: side.vol; maxValue: 1.5
        dimmed: side.muted
        selected: side.mine && root.row === side.devs.length
        onMoved: function (v) {
          root.inputSide = side.isInput; root.row = side.devs.length
          side.isInput ? Audio.setMicVolume(v) : Audio.setVolume(v)
        }
      }
    }
  }

  readonly property int colGap: Theme.s12
  readonly property real outW: Math.round((width - 2 * pad - colGap) * 0.56)
  readonly property real inW: (width - 2 * pad - colGap) - outW
  Row {
    width: parent.width; spacing: root.colGap
    Side { isInput: false; width: root.outW }
    Side { isInput: true; width: root.inW }
  }
}
