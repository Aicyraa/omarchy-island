import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../services"

// World clock. Times come from the SYSTEM (`TZ=<zone> date`), so daylight
// saving is whatever tzdata says; no hand-rolled offset math.
// Keys: ↑/↓ select · A add a zone (fuzzy search) · D remove the selected zone.
// While searching: type to filter, ↑/↓ choose, Enter add, Esc leave the search.
Item {
  id: root
  focus: true
  readonly property bool capturesEscape: searching     // Esc leaves the search first
  property string hint: searching ? "type to search · ↑/↓ choose · Enter add · Esc cancel"
                                  : "↑/↓ select · A add · D remove · Esc close"

  // ---- zones (persisted) ----
  readonly property string file: Quickshell.env("HOME") + "/.local/state/island/world-clock.json"
  property var zones: ["Local", "UTC", "America/New_York", "Europe/London", "Asia/Tokyo", "Australia/Sydney"]
  property var rows: []                  // computed: [{zone, city, time, day, offset, night, hour}]
  property int sel: 0
  property bool use24h: true

  function cityOf(z) { return z === "Local" ? "Local" : (z === "UTC" ? "UTC" : z.split("/").pop().replace(/_/g, " ")) }
  function save() { store.setText(JSON.stringify({ zones: zones })) }

  FileView { id: store; path: root.file
    onLoaded: { try { var z = JSON.parse(text()).zones; if (Array.isArray(z) && z.length) root.zones = z.slice(0, 12).filter(function (s) { return typeof s === "string" && s.length < 64 }) } catch (e) {}
                root.refresh() }
    onLoadFailed: root.refresh() }

  // 12/24h follows the bar clock format in shell.json ("HH:mm" = 24h).
  FileView { path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    onLoaded: { var m = /"format"\s*:\s*"([^"]*)"/.exec(text()); if (m) root.use24h = !(/[hA]/.test(m[1]) && !/H/.test(m[1])) } }

  // ---- refresh: once on open, then once a minute (this widget only exists while open) ----
  function refresh() {
    // Zone names are validated against tzdata's character set before they touch a shell.
    var safe = zones.filter(function (z) { return z === "Local" || /^[A-Za-z0-9_+\-\/]+$/.test(z) })
    var script = "for z in " + safe.map(function (z) { return z === "Local" ? "Local" : "'" + z + "'" }).join(" ")
      + "; do if [ \"$z\" = Local ]; then d=$(date '+%z %a %H %M %Y%m%d'); else d=$(TZ=$z date '+%z %a %H %M %Y%m%d'); fi; echo \"$z $d\"; done; echo \"LOCAL $(date '+%z %a %H %M %Y%m%d')\""
    clockProc.command = ["bash", "-c", script]
    clockProc.running = true
  }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refresh() }
  Component.onCompleted: store.reload()

  function offMin(z) { var s = z[0] === "-" ? -1 : 1; return s * (parseInt(z.slice(1, 3)) * 60 + parseInt(z.slice(3, 5))) }
  Process { id: clockProc
    stdout: StdioCollector { onStreamFinished: {
      var lines = text.trim().split("\n"), local = null, out = []
      lines.forEach(function (l) { var p = l.split(" "); if (p[0] === "LOCAL") local = p })
      if (!local) return
      lines.forEach(function (l) {
        var p = l.split(" "); if (p[0] === "LOCAL" || p.length < 6) return
        var diff = (root.offMin(p[1]) - root.offMin(local[1])) / 60
        var h = parseInt(p[3]), m = parseInt(p[4])
        var t = root.use24h ? p[3] + ":" + p[4] : ((h % 12) || 12) + ":" + p[4] + (h < 12 ? " AM" : " PM")
        out.push({ zone: p[0], city: root.cityOf(p[0]), time: t, day: p[2] !== local[2] ? p[2] : "",
                   offset: diff === 0 ? "" : (diff > 0 ? "+" : "−") + Math.abs(diff) + "h", night: h < 6 || h >= 18, hour: h + m / 60 })
      })
      root.rows = out; root.sel = Math.min(root.sel, out.length - 1)
    } } }

  // ---- search ----
  property bool searching: false
  property string query: ""
  property var allZones: []
  property int pick: 0
  // Fuzzy: every query character must appear in order; consecutive matches score higher.
  function score(name, q) {
    var n = name.toLowerCase(), qi = 0, sc = 0, last = -2
    for (var i = 0; i < n.length && qi < q.length; i++) if (n[i] === q[qi]) { sc += (i === last + 1) ? 3 : 1; last = i; qi++ }
    return qi === q.length ? sc : -1
  }
  readonly property var matches: {
    var q = query.toLowerCase().replace(/ /g, "_"), res = []
    for (var i = 0; i < allZones.length; i++) { var s = q === "" ? 0 : score(allZones[i], q); if (s >= 0) res.push({ z: allZones[i], s: s }) }
    res.sort(function (a, b) { return b.s - a.s })
    return res.slice(0, 6).map(function (r) { return r.z })
  }
  Process { id: tzList; command: ["timedatectl", "list-timezones"]
    stdout: StdioCollector { onStreamFinished: root.allZones = text.trim().split("\n") } }

  Keys.onPressed: function (e) {
    if (searching) {
      if (e.key === Qt.Key_Escape) { searching = false; e.accepted = true }
      else if (e.key === Qt.Key_Down) { pick = Math.min(pick + 1, matches.length - 1); e.accepted = true }
      else if (e.key === Qt.Key_Up) { pick = Math.max(pick - 1, 0); e.accepted = true }
      else if (e.key === Qt.Key_Backspace) { query = query.slice(0, -1); pick = 0; e.accepted = true }
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
        var z = matches[pick]
        if (z && zones.indexOf(z) < 0 && zones.length < 12) { zones = zones.concat([z]); save(); refresh() }
        searching = false; e.accepted = true }
      else if (e.text.length === 1 && e.text >= " ") { query += e.text; pick = 0; e.accepted = true }
      return
    }
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, rows.length - 1); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_A) { query = ""; pick = 0; searching = true; if (allZones.length === 0) tzList.running = true; e.accepted = true }
    else if (e.key === Qt.Key_D) {
      var r = rows[sel]
      if (r && r.zone !== "Local") { zones = zones.filter(function (x) { return x !== r.zone }); save(); refresh() }
      e.accepted = true }
  }

  Text { x: 22; y: 14; textFormat: Text.PlainText; text: "World clock"; color: Theme.text; font.pixelSize: 15; font.bold: true }
  Text { visible: !searching; anchors.right: parent.right; anchors.rightMargin: 22; y: 17; textFormat: Text.PlainText
    text: "A add · D remove"; color: Theme.textMuted; font.pixelSize: 11 }

  ListView {
    id: list
    visible: !root.searching
    x: 10; y: 44; width: root.width - 20; height: root.height - 54
    clip: true; spacing: 2; model: root.rows
    delegate: Item {
      required property var modelData
      required property int index
      width: list.width; height: 48
      Rectangle { anchors.fill: parent; radius: 14; color: root.sel === index ? Theme.surfaceRaised : "transparent" }
      Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: modelData.night ? "moon" : "sun"; size: 18
        color: modelData.night ? Theme.textMuted : Theme.warning }
      Column { x: 44; anchors.verticalCenter: parent.verticalCenter
        Text { textFormat: Text.PlainText; text: modelData.city; color: Theme.text; font.pixelSize: 13; font.bold: true }
        Text { textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 10
          text: [modelData.day, modelData.offset].filter(function (x) { return x !== "" }).join(" · ") } }
      Text { x: 190; anchors.verticalCenter: parent.verticalCenter; width: 86; textFormat: Text.PlainText
        text: modelData.time; color: Theme.text; font.pixelSize: 17; font.bold: true }
      // 24h strip: shaded 09:00-17:00 working hours and a "now" marker.
      Rectangle { id: strip; x: 290; anchors.verticalCenter: parent.verticalCenter
        width: list.width - 290 - 18; height: 10; radius: 5; color: Theme.surface
        Rectangle { x: parent.width * 9 / 24; width: parent.width * 8 / 24; height: parent.height; color: Theme.accent; opacity: 0.35 }
        Rectangle { x: parent.width * modelData.hour / 24 - 1.5; y: -3; width: 3; height: parent.height + 6; radius: 1.5; color: Theme.text } }
    }
  }
  Text { visible: !root.searching && root.rows.length === 0; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "Reading time zones…"; color: Theme.textMuted; font.pixelSize: 12 }

  // search overlay
  Item { visible: root.searching; x: 18; y: 44; width: root.width - 36; height: root.height - 54
    Rectangle { width: parent.width; height: 40; radius: 20; color: Theme.surface
      Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16 }
      Text { x: 40; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
        text: root.query === "" ? "Search time zones…" : root.query; color: root.query === "" ? Theme.textMuted : Theme.text; font.pixelSize: 13 } }
    Column { y: 48; width: parent.width; spacing: 2
      Repeater { model: root.matches
        delegate: ListItem { required property string modelData; required property int index
          width: parent.width; height: 34; icon: "globe"; title: modelData; selected: root.pick === index
          onClicked: { root.pick = index; if (root.zones.indexOf(modelData) < 0) { root.zones = root.zones.concat([modelData]); root.save(); root.refresh() } root.searching = false } } }
      Text { visible: root.matches.length === 0; textFormat: Text.PlainText; text: root.allZones.length === 0 ? "Loading…" : "No match"
        color: Theme.textMuted; font.pixelSize: 12 }
    } }
}
