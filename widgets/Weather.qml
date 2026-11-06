import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Weather: current temperature, condition and today's range, nothing more.
// NETWORK: one request to https://wttr.in when this widget opens (and on R). It is
// bounded (10 s timeout, 64 KB cap, validated fields) and never repeats on its own.
Item {
  id: root
  focus: true
  property string hint: "R refresh · Esc close"
  property string state: "loading"        // loading | ok | error
  property var w: ({ temp: 0, feels: 0, humidity: 0, desc: "", hi: 0, lo: 0, place: "" })

  function load() { state = "loading"; proc.running = true }
  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { load(); e.accepted = true } }
  Component.onCompleted: load()

  function clean(s, max) { return String(s === undefined ? "" : s).replace(/[\u0000-\u001f<>]/g, "").slice(0, max || 40) }

  Process {
    id: proc
    command: ["bash", "-c", "curl -fsS --max-time 10 --max-filesize 65536 'https://wttr.in/?format=j1'"]
    stdout: StdioCollector { onStreamFinished: {
      try {
        var j = JSON.parse(text), c = j.current_condition[0], d = j.weather[0]
        root.w = { temp: parseInt(c.temp_C), feels: parseInt(c.FeelsLikeC), humidity: parseInt(c.humidity),
                   desc: root.clean(c.weatherDesc[0].value, 40), hi: parseInt(d.maxtempC), lo: parseInt(d.mintempC),
                   place: root.clean(j.nearest_area[0].areaName[0].value, 40) }
        root.state = isNaN(root.w.temp) ? "error" : "ok"
      } catch (e) { root.state = "error" }
    } }
    onExited: function (code) { if (code !== 0) root.state = "error" }
  }

  Text { visible: root.state === "loading"; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "Fetching weather…"; color: Theme.textMuted; font.pixelSize: 13 }
  Column { visible: root.state === "error"; anchors.centerIn: parent; spacing: 6
    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "alert"; size: 26; color: Theme.warning }
    Text { anchors.horizontalCenter: parent.horizontalCenter; textFormat: Text.PlainText
      text: "Couldn't load weather (offline?)  ·  R to retry"; color: Theme.textMuted; font.pixelSize: 12 } }
  Item { visible: root.state === "ok"; anchors.fill: parent
    Icon { x: 24; y: 24; name: "cloud"; size: 44; color: Theme.text }
    Text { x: 90; y: 14; textFormat: Text.PlainText; text: root.w.temp + "°"; color: Theme.text; font.pixelSize: 44; font.bold: true }
    Column { x: 200; y: 24; spacing: 2
      Text { textFormat: Text.PlainText; text: root.w.desc; color: Theme.text; font.pixelSize: 15; font.bold: true }
      Text { textFormat: Text.PlainText; text: root.w.place; color: Theme.textMuted; font.pixelSize: 12 } }
    Row { x: 24; y: 86; spacing: 28
      Repeater { model: [ { k: "High", v: root.w.hi + "°" }, { k: "Low", v: root.w.lo + "°" },
                          { k: "Feels like", v: root.w.feels + "°" }, { k: "Humidity", v: root.w.humidity + "%" } ]
        delegate: Column { required property var modelData
          Text { textFormat: Text.PlainText; text: modelData.k; color: Theme.textMuted; font.pixelSize: 10 }
          Text { textFormat: Text.PlainText; text: modelData.v; color: Theme.text; font.pixelSize: 14; font.bold: true } } } } }
}
