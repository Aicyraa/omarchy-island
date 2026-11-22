import QtQuick
import QtQuick.Shapes
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

  dataLoading: state === "loading"
  compact: state !== "ok"
  Label { visible: root.state === "loading"; text: "Fetching weather…"; color: Theme.textMuted; font.pixelSize: Theme.typeTitle }
  Row { visible: root.state === "error"; spacing: Theme.s8
    Icon { name: "alert"; size: Theme.iconLg; color: Theme.warningInk; anchors.verticalCenter: parent.verticalCenter }
    Label { anchors.verticalCenter: parent.verticalCenter
      text: "Couldn't load weather. Check your connection."; color: Theme.textMuted; font.pixelSize: Theme.typeBody } }

  // The condition card: a soft sky tint (warm by day, cool at night), the big icon and temperature, the condition
  // and place, and High / Low on the right.
  readonly property bool night: w.icon.indexOf("moon") >= 0
  Item {
    id: heroCard
    visible: root.state === "ok"
    width: parent.width; height: 96
    Shape {
      anchors.fill: parent
      readonly property bool isBgSurface: true
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: heroCard.width; y2: 0
          GradientStop { position: 0; color: Theme.mix(Theme.surface, root.night ? Theme.accentFill : Theme.warning, root.night ? 0.30 : 0.20) }
          GradientStop { position: 1; color: Theme.surface }
        }
        PathRectangle { width: heroCard.width; height: heroCard.height; radius: Theme.tileRadius + 2 }
      }
    }
    Icon { id: heroIcon; x: Theme.s16; anchors.verticalCenter: parent.verticalCenter; name: root.w.icon; size: 52
      color: root.w.icon === "sun" ? Theme.warningInk : Theme.text }
    Label { id: heroTemp; anchors.left: heroIcon.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter
      mono: true; text: root.w.temp + "°"; color: Theme.text; font.pixelSize: 46; font.weight: Theme.weightStrong }
    Column { anchors.left: heroTemp.right; anchors.leftMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 1
      Label { text: root.w.desc; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightLabel }
      Label { text: root.w.place + (WeatherData.age > 120000 ? " · " + Math.round(WeatherData.age / 60000) + " min ago" : ""); color: Theme.textMuted; font.pixelSize: Theme.typeBody } }
    Column { anchors.right: parent.right; anchors.rightMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 4
      Row { spacing: 6; anchors.right: parent.right
        Label { text: "High"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; anchors.verticalCenter: parent.verticalCenter }
        Label { mono: true; text: root.w.hi + "°"; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter } }
      Row { spacing: 6; anchors.right: parent.right
        Label { text: "Low"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; anchors.verticalCenter: parent.verticalCenter }
        Label { mono: true; text: root.w.lo + "°"; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter } }
    }
  }
  Row { visible: root.state === "ok"; width: parent.width; spacing: Theme.s12
    Repeater { model: [ { k: "Feels like", v: root.w.feels + "°" }, { k: "Humidity", v: root.w.humidity + "%" } ]
      delegate: StatTile { required property var modelData; width: (parent.width - Theme.s12) / 2; label: modelData.k; value: modelData.v
        fraction: modelData.k === "Humidity" ? root.w.humidity / 100 : -1 } } }
}
