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

  Row { visible: root.state === "ok"; width: parent.width; spacing: Theme.s16
    Icon { name: root.w.icon; size: 44; color: root.w.icon === "sun" ? Theme.warningInk : Theme.text; anchors.verticalCenter: parent.verticalCenter }
    Text { textFormat: Text.PlainText; text: root.w.temp + "°"; color: Theme.text; font.pixelSize: 44; font.weight: Theme.weightStrong; anchors.verticalCenter: parent.verticalCenter }
    Column { anchors.verticalCenter: parent.verticalCenter
      Text { textFormat: Text.PlainText; text: root.w.desc; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong }
      Text { textFormat: Text.PlainText; text: root.w.place; color: Theme.text; font.pixelSize: 12 }
      Text { textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 11
        text: (root.location !== "" ? "custom location" : "from your IP address") + (WeatherData.age > 120000 ? " · " + Math.round(WeatherData.age / 60000) + " min ago" : "") } }
  }
  Row { visible: root.state === "ok"; width: parent.width
    Repeater { model: [ { k: "High", v: root.w.hi + "°" }, { k: "Low", v: root.w.lo + "°" },
                        { k: "Feels like", v: root.w.feels + "°" }, { k: "Humidity", v: root.w.humidity + "%" } ]
      delegate: Column { required property var modelData; width: parent.width / 4
        Text { textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 11 }
        Text { textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 14; font.weight: Theme.weightLabel } } } }
}
