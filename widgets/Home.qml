import QtQuick
import ".."
import "../services"

// Home: Android-style quick settings. A grid of toggle tiles with live state
// plus large volume and brightness sliders.
//
// Keys: arrows move (←/→ on a slider adjusts it), Enter toggles the selected
// tile, 1-6 toggle a tile directly, O opens the selected item's detail widget,
// M mutes. Esc closes (Island).
Item {
  id: root
  focus: true
  property string hint: "1-6 toggle · arrows move · Enter toggle · O details · M mute · Esc close"

  // 0-5 are tiles, 6 volume slider, 7 brightness slider.
  property int sel: 0

  readonly property var tiles: [
    { icon: Net.enabled ? "wifi" : "wifi-off", title: "Wi-Fi",
      sub: !Net.hasWifi ? "No adapter" : (!Net.enabled ? "Off" : (Net.connected ? Net.ssid : "Not connected")),
      on: Net.enabled, show: Net.hasWifi, toggle: function () { Net.toggle() }, open: "wifi" },
    { icon: "bluetooth", title: "Bluetooth",
      sub: !Bt.hasAdapter ? "No adapter" : (!Bt.enabled ? "Off" : (Bt.connectedName !== "" ? Bt.connectedName : "On")),
      on: Bt.enabled, show: Bt.hasAdapter, toggle: function () { Bt.toggle() }, open: "bluetooth" },
    { icon: "focus", title: "Focus", sub: Indicators.dnd ? "On" : "Off",
      on: Indicators.dnd, show: true, toggle: function () { Indicators.toggleDnd() }, open: "notifications" },
    { icon: "moon", title: "Night light", sub: Indicators.nightLight ? "On" : "Off",
      on: Indicators.nightLight, show: true, toggle: function () { Indicators.toggleNightLight() }, open: "display" },
    { icon: "coffee", title: "Stay awake", sub: Indicators.stayAwake ? "On" : "Off",
      on: Indicators.stayAwake, show: true, toggle: function () { Indicators.toggleStayAwake() }, open: "battery" },
    { icon: "mic-dictate", title: "Dictation", sub: Indicators.dictation === "idle" ? "Off" : Indicators.dictation,
      on: Indicators.dictation !== "idle", show: Indicators.dictationAvailable,
      toggle: function () { Indicators.toggleDictation() }, open: "" }
  ]

  function activate(i) { var t = tiles[i]; if (t && t.show) t.toggle() }
  function adjust(delta) {
    if (sel === 6) Audio.setVolume(Audio.volume + delta)
    else if (sel === 7) Brightness.set(Brightness.level + delta)
  }
  function move(dx, dy) {
    if (sel < 6) {
      if (dx !== 0) { var n = sel + dx; if (n >= 0 && n < 6 && (n >> 1) === (sel >> 1)) sel = n }
      else if (dy > 0) sel = (sel + 2 < 6) ? sel + 2 : 6
      else if (dy < 0 && sel >= 2) sel -= 2
    } else if (dx !== 0) adjust(dx * 0.05)
    else sel = Math.max(sel >= 6 && dy < 0 ? (sel === 6 ? 4 : 6) : sel + dy, 0)
  }

  Keys.onPressed: function (e) {
    if (e.key >= Qt.Key_1 && e.key <= Qt.Key_6) { var i = e.key - Qt.Key_1; sel = i; activate(i); e.accepted = true }
    else if (e.key === Qt.Key_Left)  { move(-1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Right) { move(1, 0); e.accepted = true }
    else if (e.key === Qt.Key_Up)    { move(0, -1); e.accepted = true }
    else if (e.key === Qt.Key_Down)  { move(0, 1); e.accepted = true }
    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
      if (sel < 6) activate(sel); else if (sel === 6) Audio.toggleMute(); e.accepted = true }
    else if (e.key === Qt.Key_M) { Audio.toggleMute(); e.accepted = true }
    else if (e.key === Qt.Key_O) {
      var name = sel < 6 ? tiles[sel].open : (sel === 6 ? "audio" : "display")
      if (name !== "") IslandState.openWidget(name, ""); e.accepted = true }
  }

  // Read hardware state once when the widget opens (no polling).
  Component.onCompleted: { Brightness.refresh(); Indicators.refresh() }

  // ---- tile grid: 2 columns; hidden tiles (no adapter) collapse out ----
  Grid {
    id: grid
    x: 18; y: 18
    columns: 2; spacing: 10
    Repeater {
      model: root.tiles
      delegate: Tile {
        required property var modelData
        required property int index
        visible: modelData.show
        width: (root.width - 36 - 10) / 2; height: 56
        icon: modelData.icon; title: modelData.title; subtitle: modelData.sub
        on: modelData.on
        selected: root.sel === index
        keyHint: String(index + 1)
        onClicked: { root.sel = index; modelData.toggle() }
        onRightClicked: if (modelData.open !== "") IslandState.openWidget(modelData.open, "")
      }
    }
  }

  // ---- sliders ----
  Column {
    x: 18; y: 18 + 3 * 56 + 2 * 10 + 16
    width: root.width - 36
    spacing: 10
    PillSlider {
      width: parent.width
      icon: "volume"                       // replaced by the animated VolumeIcon below
      iconItem: VolumeIcon { level: Audio.volume; muted: Audio.muted; size: 20; color: Theme.accentText }
      value: Audio.muted ? 0 : Audio.volume
      selected: root.sel === 6
      onMoved: function (v) { root.sel = 6; Audio.setVolume(v) }
    }
    PillSlider {
      width: parent.width
      icon: "sun"
      value: Brightness.level
      visible: Brightness.available
      selected: root.sel === 7
      onMoved: function (v) { root.sel = 7; Brightness.set(v) }
    }
  }
}
