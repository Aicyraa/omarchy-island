pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Core"

// WeatherData: temperature, condition and today's range from wttr.in, with day/night aware icons.
// NETWORK: one bounded request (10 s timeout, 64 KB cap, validated fields) when the data is older than `ttl`
// (10 min): at startup, when the pointer nears the island, or when the Weather widget opens (or R). The last
// good reading is cached on disk, so the widget opens with it instantly and refreshes in the background.
// LOCATION: auto-detected from your IP unless `weatherLocation` is set in ~/.local/state/island/state.json.
Singleton {
  id: root
  readonly property real ttl: 10 * 60 * 1000
  property string state: "empty"          // empty (nothing yet) | loading | ok | error
  property var w: ({ temp: 0, feels: 0, humidity: 0, desc: "", hi: 0, lo: 0, place: "", icon: "cloud" })
  property real updatedAt: 0
  readonly property bool hasData: updatedAt > 0
  readonly property string location: IslandState.weatherLocation.replace(/[^A-Za-z0-9 ,.\-]/g, "").slice(0, 60)
  readonly property real age: updatedAt > 0 ? Date.now() - updatedAt : Infinity

  function refresh() { if (proc.running) return; if (!hasData) state = "loading"; proc.running = true }
  function refreshIfStale() { if (age > ttl) refresh() }

  Component.onCompleted: {
    var c = Cache.get("weather")
    if (c && c.location === location && c.w) { w = c.w; updatedAt = Cache.age("weather") === Infinity ? 0 : Date.now() - Cache.age("weather"); state = "ok" }
  }
  onLocationChanged: { updatedAt = 0; state = "empty" }

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
        // wttr.in gives no local clock. For an auto-detected place this machine's clock IS the local time.
        // For a custom location, estimate it from the (UTC) observation time and the longitude.
        var now = -1
        if (root.location === "") { var t = new Date(); now = t.getHours() * 60 + t.getMinutes() }
        else {
          var obs = root.mins(c.observation_time), lon = parseFloat(j.nearest_area[0].longitude)
          if (obs >= 0 && !isNaN(lon)) now = ((obs + Math.round(lon / 15 * 60)) % 1440 + 1440) % 1440
        }
        var rise = root.mins(a.sunrise), set = root.mins(a.sunset)
        var isDay = (now < 0 || rise < 0 || set < 0) ? true : (now >= rise && now < set)
        var nw = { temp: parseInt(c.temp_C), feels: parseInt(c.FeelsLikeC), humidity: parseInt(c.humidity),
                   desc: root.clean(c.weatherDesc[0].value, 40), hi: parseInt(d.maxtempC), lo: parseInt(d.mintempC),
                   place: root.clean(j.nearest_area[0].areaName[0].value, 40), icon: root.iconFor(c.weatherCode, isDay) }
        if (isNaN(nw.temp)) throw new Error("bad")
        root.w = nw; root.updatedAt = Date.now(); root.state = "ok"
        Cache.put("weather", { location: root.location, w: nw })
      } catch (e) { root.state = root.hasData ? "ok" : "error" }       // keep showing the last good reading
    } }
    onExited: function (code) { if (code !== 0) root.state = root.hasData ? "ok" : "error" }
  }
}
