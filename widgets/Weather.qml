import QtQuick
import ".."
import "../services"

// Weather: temperature, condition and today's range, with the right icon for the
// condition AND the time of day (a clear night shows a moon, not a cloud).
// NETWORK: one request to https://wttr.in when this opens (and on R); bounded
// (10 s timeout, 64 KB cap, validated fields); never repeats on its own.
// LOCATION: auto-detected from your IP unless `weatherLocation` is set in
// ~/.local/state/island/state.json (e.g. "Manila"). The panel says which is in use.
WidgetPanel {
  id: root
  preferredWidth: 440
  hint: "R refresh · Esc close"
  // From the WeatherData service: the last good reading is cached on disk, so this opens with it and refreshes behind.
  readonly property string state: WeatherData.state === "empty" ? "loading" : WeatherData.state
  readonly property var w: WeatherData.w
  readonly property string location: WeatherData.location

  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { WeatherData.refresh(); e.accepted = true } }
  Component.onCompleted: WeatherData.refreshIfStale()

  compact: state !== "ok"
  Text { visible: root.state === "loading"; textFormat: Text.PlainText; text: "Fetching weather…"; color: Theme.textMuted; font.pixelSize: 13 }
  Row { visible: root.state === "error"; spacing: Theme.s8
    Icon { name: "alert"; size: Theme.iconLg; color: Theme.warningInk; anchors.verticalCenter: parent.verticalCenter }
    Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter
      text: "Couldn't load weather. Check your connection."; color: Theme.textMuted; font.pixelSize: 12 } }

  // The condition card: a soft sky tint (warm by day, cool at night), the big icon and temperature, the condition
  // and place, and High / Low on the right.
  readonly property bool night: w.icon.indexOf("moon") >= 0
  Rectangle {
    visible: root.state === "ok"; antialiasing: true
    width: parent.width; height: 96; radius: Theme.tileRadius + 2
    gradient: Gradient { orientation: Gradient.Horizontal
      GradientStop { position: 0; color: Theme.mix(Theme.surface, root.night ? Theme.accentFill : Theme.warning, root.night ? 0.30 : 0.20) }
      GradientStop { position: 1; color: Theme.surface } }
    Icon { id: heroIcon; x: Theme.s16; anchors.verticalCenter: parent.verticalCenter; name: root.w.icon; size: 52
      color: root.w.icon === "sun" ? Theme.warningInk : Theme.text }
    Text { id: heroTemp; anchors.left: heroIcon.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText; text: root.w.temp + "°"; color: Theme.text; font.pixelSize: 46; font.weight: Theme.weightStrong }
    Column { anchors.left: heroTemp.right; anchors.leftMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 1
      Text { textFormat: Text.PlainText; text: root.w.desc; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightLabel }
      Text { textFormat: Text.PlainText; text: root.w.place + (WeatherData.age > 120000 ? " · " + Math.round(WeatherData.age / 60000) + " min ago" : ""); color: Theme.textMuted; font.pixelSize: 12 } }
    Column { anchors.right: parent.right; anchors.rightMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 4
      Row { spacing: 6; anchors.right: parent.right
        Text { text: "High"; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.w.hi + "°"; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter } }
      Row { spacing: 6; anchors.right: parent.right
        Text { text: "Low"; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.w.lo + "°"; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter } }
    }
  }
  Row { visible: root.state === "ok"; width: parent.width; spacing: Theme.s12
    Repeater { model: [ { k: "Feels like", v: root.w.feels + "°" }, { k: "Humidity", v: root.w.humidity + "%" } ]
      delegate: StatTile { required property var modelData; width: (parent.width - Theme.s12) / 2; label: modelData.k; value: modelData.v
        fraction: modelData.k === "Humidity" ? root.w.humidity / 100 : -1 } } }
}
