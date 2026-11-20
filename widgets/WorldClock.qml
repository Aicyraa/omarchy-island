import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../services"

// World clock: vertically centered globe hero card on the left, clean city list with
// 24h daylight strips on the right, and a real keyboard-editable search box for adding zones.
// Keys: ↑/↓ select · A add a zone · D remove selected · Esc leave search / close.
WidgetPanel {
  id: root
  preferredWidth: 660
  readonly property bool capturesEscape: searching
  readonly property bool wantsKeyboard: searching
  hint: searching ? "type to search · ↑/↓ choose · Enter add · Esc cancel" : "↑/↓ select · A add · D remove · Esc close"

  readonly property string file: Quickshell.env("HOME") + "/.local/state/island/world-clock.json"
  property var zones: ["Local", "UTC", "America/New_York", "Europe/London", "Asia/Tokyo", "Australia/Sydney"]
  property var rows: []
  property int sel: 0
  property bool use24h: true
  dataLoading: rows.length === 0
  property string localZone: ""
  property var cityMap: ({})
  readonly property var sunMarkers: {
    var out = []
    rows.forEach(function (r, i) {
      var z = r.zone === "Local" ? localZone : r.zone, c = cityMap[z]
      if (c) out.push({ lat: c[0], lon: c[1], sel: i === sel })
    })
    return out
  }
  readonly property real focusLon: {
    var r = rows[sel]; if (!r) return 0
    var c = cityMap[r.zone === "Local" ? localZone : r.zone]
    return c ? c[1] : 0
  }
  FileView {
    path: Qt.resolvedUrl("../assets/cities.json").toString().replace("file://", ""); printErrors: false
    onLoaded: { try { var m = Object.assign({}, root.cityMap); JSON.parse(text()).forEach(function (c) { m[c[1]] = [c[2], c[3]] }); root.cityMap = m } catch (e) {} }
  }
  function isoCoord(t) {
    var m = /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/.exec(t); if (!m) return null
    var la = parseInt(m[2]) + parseInt(m[3]) / 60 + (m[4] ? parseInt(m[4]) / 3600 : 0)
    var lo = parseInt(m[6]) + parseInt(m[7]) / 60 + (m[8] ? parseInt(m[8]) / 3600 : 0)
    return [m[1] === "-" ? -la : la, m[5] === "-" ? -lo : lo]
  }
  FileView {
    path: "/usr/share/zoneinfo/zone.tab"; printErrors: false
    onLoaded: {
      var m = Object.assign({}, root.cityMap)
      text().split("\n").forEach(function (l) { if (l[0] === "#" || !l) return; var f = l.split("\t"); var c = root.isoCoord(f[1]); if (c && !m[f[2]]) m[f[2]] = c })
      root.cityMap = m
    }
  }
  Process {
    running: true; command: ["timedatectl", "show", "-p", "Timezone", "--value"]
    stdout: StdioCollector { onStreamFinished: root.localZone = text.trim() }
  }

  function cityOf(z) { return z === "Local" ? "Local" : (z === "UTC" ? "UTC" : z.split("/").pop().replace(/_/g, " ")) }
  function save() { store.setText(JSON.stringify({ zones: zones })) }

  FileView {
    id: store; path: root.file; printErrors: false
    onLoaded: {
      try { var z = JSON.parse(text()).zones; if (Array.isArray(z) && z.length) root.zones = z.slice(0, 12).filter(function (s) { return typeof s === "string" && s.length < 64 }) } catch (e) {}
      root.refresh()
    }
    onLoadFailed: root.refresh()
  }
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    onLoaded: { var m = /"format"\s*:\s*"([^"]*)"/.exec(text()); if (m) root.use24h = !(/[hA]/.test(m[1]) && !/H/.test(m[1])) }
  }

  function refresh() {
    var safe = zones.filter(function (z) { return z === "Local" || /^[A-Za-z0-9_+\-\/]+$/.test(z) })
    var script = "for z in " + safe.map(function (z) { return z === "Local" ? "Local" : "'" + z + "'" }).join(" ")
      + "; do if [ \"$z\" = Local ]; then d=$(date '+%z %a %H %M %Y%m%d'); else d=$(TZ=$z date '+%z %a %H %M %Y%m%d'); fi; echo \"$z $d\"; done; echo \"LOCAL $(date '+%z %a %H %M %Y%m%d')\""
    clockProc.command = ["bash", "-c", script]; clockProc.running = true
  }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refresh() }
  Component.onCompleted: store.reload()

  function offMin(z) { var s = z[0] === "-" ? -1 : 1; return s * (parseInt(z.slice(1, 3)) * 60 + parseInt(z.slice(3, 5))) }
  Process {
    id: clockProc
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
      root.rows = out; root.sel = Math.min(root.sel, Math.max(0, out.length - 1))
    } }
  }

  // ---- search ----
  property bool searching: false
  property string query: ""
  property var allZones: []
  property int pick: 0
  function openSearch() {
    query = ""; pick = 0; searching = true
    if (allZones.length === 0) tzList.running = true
    Qt.callLater(function () { tzInput.text = ""; tzInput.forceActiveFocus() })
  }
  function closeSearch() {
    searching = false
    root.forceActiveFocus()
  }
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
  function addZone(z) { if (z && zones.indexOf(z) < 0 && zones.length < 12) { zones = zones.concat([z]); save(); refresh() } closeSearch() }
  Process {
    id: tzList; command: ["timedatectl", "list-timezones"]
    stdout: StdioCollector { onStreamFinished: root.allZones = text.trim().split("\n") }
  }

  Keys.onPressed: function (e) {
    if (searching) {
      if (e.key === Qt.Key_Escape) { closeSearch(); e.accepted = true }
      return
    }
    if (e.key === Qt.Key_Down) { sel = Math.min(sel + 1, Math.max(0, rows.length - 1)); e.accepted = true }
    else if (e.key === Qt.Key_Up) { sel = Math.max(sel - 1, 0); e.accepted = true }
    else if (e.key === Qt.Key_A) { openSearch(); e.accepted = true }
    else if (e.key === Qt.Key_D) {
      var r = rows[sel]
      if (r && r.zone !== "Local") { zones = zones.filter(function (x) { return x !== r.zone }); save(); refresh() }
      e.accepted = true
    }
  }

  // ---- Centered asymmetrical composition: centered globe hero on left, city rows on right ----
  Item {
    width: parent.width
    height: Math.max(leftCard.height, right.height)

    Rectangle {
      id: leftCard
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 204
      height: leftCol.implicitHeight + 2 * Theme.s12
      radius: Theme.tileRadius + 2; color: Theme.surface; antialiasing: true

      Column {
        id: leftCol
        x: Theme.s12; y: Theme.s12; width: parent.width - 2 * Theme.s12; spacing: Theme.s8
        GlobeView {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 164; height: 164; markers: root.sunMarkers; focusLon: root.focusLon
        }
        Column {
          width: parent.width; spacing: 2
          Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; textFormat: Text.PlainText
            text: root.rows[root.sel] ? root.rows[root.sel].city : ""; color: Theme.text
            font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong
          }
          Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText
            text: root.rows[root.sel] ? (root.rows[root.sel].time + (root.rows[root.sel].night ? " · Night" : " · Day")) : ""
            color: Theme.textMuted; font.pixelSize: Theme.typeLabel
          }
        }
        Rectangle {
          antialiasing: true; visible: !root.searching; width: parent.width; height: 30; radius: 15
          color: addArea.containsMouse ? Theme.mix(Theme.surfaceRaised, Theme.text, 0.14) : Theme.surfaceRaised
          Behavior on color { ColorAnimation { duration: 120 } }
          Row {
            anchors.centerIn: parent; spacing: 6
            Icon { name: "plus"; size: Theme.iconSm; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { textFormat: Text.PlainText; text: "Add city"; color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea { id: addArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openSearch() }
        }
      }
    }

    Item {
      id: right
      anchors.left: leftCard.right; anchors.leftMargin: Theme.s16
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: root.searching ? searchCol.implicitHeight : Math.max(listCol.implicitHeight, 44)

      Column {
        id: listCol
        visible: !root.searching && root.rows.length > 0
        width: parent.width; spacing: Theme.rowGap
        Repeater {
          model: root.rows
          delegate: Item {
            id: rowItem
            required property var modelData
            required property int index
            width: parent.width; height: 48
            FocusTarget { selected: root.sel === index && !root.searching; target: parent }
            Icon {
              id: dayIcon; x: 0; anchors.verticalCenter: parent.verticalCenter
              name: modelData.night ? "moon" : "sun"; size: Theme.iconMd
              color: modelData.night ? Theme.textMuted : Theme.warningInk
            }
            Column {
              anchors.left: dayIcon.right; anchors.leftMargin: Theme.s12
              anchors.right: timeText.left; anchors.rightMargin: Theme.s8
              anchors.verticalCenter: parent.verticalCenter; spacing: 1
              Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.city; color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightLabel }
              Text {
                width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: Theme.typeCaption
                text: [modelData.day, modelData.offset].filter(function (x) { return x !== "" }).join(" · "); visible: text !== ""
              }
            }
            Text {
              id: timeText; anchors.right: barBox.left; anchors.rightMargin: Theme.s12
              width: 72; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText; text: modelData.time; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong
            }
            // 24h daylight & working-hours strip
            Item {
              id: barBox; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
              width: Math.max(108, Math.round(parent.width * 0.34)); height: 16
              Rectangle { antialiasing: true; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 8; radius: 4; color: Theme.outline; opacity: 0.30 }
              Rectangle { x: parent.width * 9 / 24; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 8 / 24; height: 8; radius: 2; color: Theme.accentInk; opacity: 0.55 }
              Rectangle { antialiasing: true; x: parent.width * modelData.hour / 24 - 1.5; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 16; radius: 1.5; color: Theme.text }
            }
            MouseArea { anchors.fill: parent; anchors.leftMargin: -Theme.s8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sel = rowItem.index }
          }
        }
      }
      Text {
        visible: !root.searching && root.rows.length === 0; textFormat: Text.PlainText
        text: "Reading time zones…"; color: Theme.textMuted; font.pixelSize: Theme.typeBody
      }

      // ---- keyboard-editable search ----
      Column {
        id: searchCol; visible: root.searching; width: parent.width; spacing: Theme.s8
        Rectangle {
          antialiasing: true; width: parent.width; height: 40; radius: Theme.tileRadius; color: Theme.surface
          border.width: tzInput.activeFocus ? 1 : 0; border.color: Theme.accentInk
          Icon { id: sIcon; x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: Theme.iconSm; color: Theme.textMuted }
          TextInput {
            id: tzInput
            anchors.left: sIcon.right; anchors.leftMargin: Theme.s8
            anchors.right: parent.right; anchors.rightMargin: Theme.s12
            anchors.verticalCenter: parent.verticalCenter
            selectByMouse: true; color: Theme.text; selectionColor: Theme.accentFill; selectedTextColor: Theme.accentText
            font.pixelSize: Theme.typeTitle; font.weight: Theme.weightLabel
            onTextChanged: { root.query = text; root.pick = 0 }
            Keys.onPressed: function (e) {
              if (e.key === Qt.Key_Escape) { root.closeSearch(); e.accepted = true }
              else if (e.key === Qt.Key_Down) { root.pick = Math.min(root.pick + 1, Math.max(0, root.matches.length - 1)); e.accepted = true }
              else if (e.key === Qt.Key_Up) { root.pick = Math.max(root.pick - 1, 0); e.accepted = true }
              else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (root.matches[root.pick]) root.addZone(root.matches[root.pick]); e.accepted = true }
            }
          }
          Text {
            visible: tzInput.text === ""; anchors.left: tzInput.left; anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText; text: "Search time zones…"; color: Theme.textMuted; font.pixelSize: Theme.typeBody
          }
          MouseArea { anchors.fill: parent; z: -1; onClicked: tzInput.forceActiveFocus() }
        }
        Repeater {
          model: root.matches
          delegate: ListRow {
            required property string modelData; required property int index
            width: parent.width; height: 38; icon: "globe"; title: modelData; selected: root.pick === index
            onClicked: root.addZone(modelData)
          }
        }
        Text {
          visible: root.matches.length === 0; textFormat: Text.PlainText
          text: root.allZones.length === 0 ? "Loading…" : "No match"; color: Theme.textMuted; font.pixelSize: Theme.typeBody
        }
      }
    }
  }
}
