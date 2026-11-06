import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../services"

// World clock. Times come from the SYSTEM (`TZ=<zone> date`), so daylight saving is
// whatever tzdata says; no hand-rolled offset math.
// Keys: ↑/↓ select · A add a zone (fuzzy search) · D remove the selected zone.
// While searching: type to filter, ↑/↓ choose, Enter add, Esc leaves the search.
WidgetPanel {
  id: root
  preferredWidth: 620
  readonly property bool capturesEscape: searching     // Esc leaves the search first
  hint: searching ? "type to search · ↑/↓ choose · Enter add · Esc cancel" : "↑/↓ select · A add · D remove · Esc close"

  readonly property string file: Quickshell.env("HOME") + "/.local/state/island/world-clock.json"
  property var zones: ["Local", "UTC", "America/New_York", "Europe/London", "Asia/Tokyo", "Australia/Sydney"]
  property var rows: []                  // [{zone, city, time, day, offset, night, hour}]
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

  // Refresh once on open, then once a minute (this widget only exists while open).
  function refresh() {
    var safe = zones.filter(function (z) { return z === "Local" || /^[A-Za-z0-9_+\-\/]+$/.test(z) })   // validated before it touches a shell
    var script = "for z in " + safe.map(function (z) { return z === "Local" ? "Local" : "'" + z + "'" }).join(" ")
      + "; do if [ \"$z\" = Local ]; then d=$(date '+%z %a %H %M %Y%m%d'); else d=$(TZ=$z date '+%z %a %H %M %Y%m%d'); fi; echo \"$z $d\"; done; echo \"LOCAL $(date '+%z %a %H %M %Y%m%d')\""
    clockProc.command = ["bash", "-c", script]; clockProc.running = true
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
  function addZone(z) { if (z && zones.indexOf(z) < 0 && zones.length < 12) { zones = zones.concat([z]); save(); refresh() } searching = false }
  Process { id: tzList; command: ["timedatectl", "list-timezones"]
    stdout: StdioCollector { onStreamFinished: root.allZones = text.trim().split("\n") } }

  Keys.onPressed: function (e) {
    if (searching) {
      if (e.key === Qt.Key_Escape) { searching = false; e.accepted = true }
      else if (e.key === Qt.Key_Down) { pick = Math.min(pick + 1, matches.length - 1); e.accepted = true }
      else if (e.key === Qt.Key_Up) { pick = Math.max(pick - 1, 0); e.accepted = true }
      else if (e.key === Qt.Key_Backspace) { query = query.slice(0, -1); pick = 0; e.accepted = true }
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { addZone(matches[pick]); e.accepted = true }
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

  // ---- header ----
  Item { width: parent.width; height: 28
    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "World clock"; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong }
    Rectangle { visible: !root.searching; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      height: 28; width: addLabel.implicitWidth + Theme.s16 * 2; radius: 14; color: Theme.surface
      Text { id: addLabel; anchors.centerIn: parent; textFormat: Text.PlainText; text: "Add city"; color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel }
      MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.query = ""; root.pick = 0; root.searching = true } } } }

  // ---- rows (hidden while searching) ----
  Column {
    visible: !root.searching && root.rows.length > 0
    width: parent.width; spacing: Theme.rowGap
    Repeater {
      model: root.rows
      delegate: Item {
        required property var modelData
        required property int index
        width: parent.width; height: 48
        // Highlight first (it bleeds to the pill edge) ...
        FocusTarget { selected: root.sel === index && !root.searching; target: parent }
        Icon { x: 0; anchors.verticalCenter: parent.verticalCenter; name: modelData.night ? "moon" : "sun"; size: Theme.iconMd
          color: modelData.night ? Theme.textMuted : Theme.warningInk }
        Column { x: Theme.iconMd + Theme.s12; anchors.verticalCenter: parent.verticalCenter
          Text { textFormat: Text.PlainText; text: modelData.city; color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
          Text { textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 11
            text: [modelData.day, modelData.offset].filter(function (x) { return x !== "" }).join(" · "); visible: text !== "" } }
        Text { x: 170; width: 88; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
          text: modelData.time; color: Theme.text; font.pixelSize: 17; font.weight: Theme.weightStrong }
        // ... then the 24h strip ABOVE it, so every row (including the selected one) shows its track:
        // a shaded 09:00-17:00 working band and a "now" marker.
        Rectangle { x: 270; anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 270; height: 10; radius: 5; color: Theme.outline; opacity: 0.35 }
        Rectangle { x: 270 + (parent.width - 270) * 9 / 24; anchors.verticalCenter: parent.verticalCenter
          width: (parent.width - 270) * 8 / 24; height: 10; color: Theme.accentInk; opacity: 0.55 }
        Rectangle { x: 270 + (parent.width - 270) * modelData.hour / 24 - 1.5; anchors.verticalCenter: parent.verticalCenter
          width: 3; height: 16; radius: 1.5; color: Theme.text }
        onWidthChanged: {}
      }
    }
  }
  Text { visible: !root.searching && root.rows.length === 0; textFormat: Text.PlainText
    text: "Reading time zones…"; color: Theme.textMuted; font.pixelSize: 12 }

  // ---- search overlay ----
  Column { visible: root.searching; width: parent.width; spacing: Theme.s8
    Rectangle { width: parent.width; height: 40; radius: 20; color: Theme.surface
      Icon { x: Theme.s16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: Theme.iconSm }
      Text { x: Theme.s16 + Theme.iconSm + Theme.s8; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
        text: root.query === "" ? "Search time zones…" : root.query; color: root.query === "" ? Theme.textMuted : Theme.text; font.pixelSize: 13 } }
    Repeater { model: root.matches
      delegate: ListRow { required property string modelData; required property int index
        width: parent.width; height: 36; icon: "globe"; title: modelData; selected: root.pick === index
        onClicked: root.addZone(modelData) } }
    Text { visible: root.matches.length === 0; textFormat: Text.PlainText; text: root.allZones.length === 0 ? "Loading…" : "No match"
      color: Theme.textMuted; font.pixelSize: 12 }
  }
}
