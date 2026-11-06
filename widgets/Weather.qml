import QtQuick
import Quickshell.Io
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
  property string state: "loading"        // loading | ok | error
  property var w: ({ temp: 0, feels: 0, humidity: 0, desc: "", hi: 0, lo: 0, place: "", icon: "cloud" })
  readonly property string location: IslandState.weatherLocation.replace(/[^A-Za-z0-9 ,.\-]/g, "").slice(0, 60)

  function load() { state = "loading"; proc.running = true }
  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { load(); e.accepted = true } }
  Component.onCompleted: load()

  function clean(s, max) { return String(s === undefined ? "" : s).replace(/[\u0000-\u001f<>]/g, "").slice(0, max || 40) }
  // "06:02 AM" -> minutes since midnight
  function mins(t) { var m = /(\d+):(\d+)\s*(AM|PM)/i.exec(t || ""); if (!m) return -1
    var h = parseInt(m[1]) % 12 + (m[3].toUpperCase() === "PM" ? 12 : 0); return h * 60 + parseInt(m[2]) }
  // wttr.in weatherCode -> icon. isDay picks the sun or moon variants.
  function iconFor(code, isDay) {
    var c = parseInt(code)
    if (c === 113) return isDay ? "sun" : "moon"
    if (c === 116) return isDay ? "cloud-sun" : "cloud-moon"
    if ([119, 122].indexOf(c) >= 0) return "cloud"
    if ([143, 248, 260].indexOf(c) >= 0) return "fog"
    if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "cloud-bolt"
    if ([179, 182, 185, 227, 230, 281, 284, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].indexOf(c) >= 0) return "cloud-snow"
    if (c >= 176 && c <= 377) return "rain"
    return "cloud"
  }

  Process {
    id: proc
    command: ["curl", "-fsS", "--max-time", "10", "--max-filesize", "65536",
              "https://wttr.in/" + encodeURIComponent(root.location) + "?format=j1"]
    stdout: StdioCollector { onStreamFinished: {
      try {
        var j = JSON.parse(text), c = j.current_condition[0], d = j.weather[0], a = d.astronomy[0]
        // Local observation time vs sunrise/sunset decides day or night.
        // wttr.in gives no local clock. For an auto-detected place this machine's clock IS the local
        // time. For a custom location, estimate it from the (UTC) observation time and the longitude.
        var now = -1
        if (root.location === "") { var t = new Date(); now = t.getHours() * 60 + t.getMinutes() }
        else {
          var obs = root.mins(c.observation_time), lon = parseFloat(j.nearest_area[0].longitude)
          if (obs >= 0 && !isNaN(lon)) now = ((obs + Math.round(lon / 15 * 60)) % 1440 + 1440) % 1440
        }
        var rise = root.mins(a.sunrise), set = root.mins(a.sunset)
        var isDay = (now < 0 || rise < 0 || set < 0) ? true : (now >= rise && now < set)
        root.w = { temp: parseInt(c.temp_C), feels: parseInt(c.FeelsLikeC), humidity: parseInt(c.humidity),
                   desc: root.clean(c.weatherDesc[0].value, 40), hi: parseInt(d.maxtempC), lo: parseInt(d.mintempC),
                   place: root.clean(j.nearest_area[0].areaName[0].value, 40), icon: root.iconFor(c.weatherCode, isDay) }
        root.state = isNaN(root.w.temp) ? "error" : "ok"
      } catch (e) { root.state = "error" }
    } }
    onExited: function (code) { if (code !== 0) root.state = "error" }
  }

  compact: state !== "ok"
  Text { visible: root.state === "loading"; textFormat: Text.PlainText; text: "Fetching weather…"; color: Theme.textMuted; font.pixelSize: 13 }
  Row { visible: root.state === "error"; spacing: Theme.s8
    Icon { name: "alert"; size: Theme.iconLg; color: Theme.warningInk; anchors.verticalCenter: parent.verticalCenter }
    Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter
      text: "Couldn't load weather (offline?)  ·  R to retry"; color: Theme.textMuted; font.pixelSize: 12 } }

  Row { visible: root.state === "ok"; width: parent.width; spacing: Theme.s16
    Icon { name: root.w.icon; size: 44; color: root.w.icon === "sun" ? Theme.warningInk : Theme.text; anchors.verticalCenter: parent.verticalCenter }
    Text { textFormat: Text.PlainText; text: root.w.temp + "°"; color: Theme.text; font.pixelSize: 44; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
    Column { anchors.verticalCenter: parent.verticalCenter
      Text { textFormat: Text.PlainText; text: root.w.desc; color: Theme.text; font.pixelSize: 15; font.bold: true }
      Text { textFormat: Text.PlainText; text: root.w.place; color: Theme.text; font.pixelSize: 12 }
      Text { textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 10
        text: root.location !== "" ? "location set in state.json" : "auto-detected by IP" } }
  }
  Row { visible: root.state === "ok"; width: parent.width
    Repeater { model: [ { k: "High", v: root.w.hi + "°" }, { k: "Low", v: root.w.lo + "°" },
                        { k: "Feels like", v: root.w.feels + "°" }, { k: "Humidity", v: root.w.humidity + "%" } ]
      delegate: Column { required property var modelData; width: parent.width / 4
        Text { textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 10 }
        Text { textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 14; font.bold: true } } } }
}
