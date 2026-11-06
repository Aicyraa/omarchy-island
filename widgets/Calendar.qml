import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Calendar: month grid. Today is accent-filled, weekends are dimmed, week
// numbers are optional (N). The first weekday follows the system locale.
// Keys: ←/→ or H/L month · PgUp/PgDn year · ↑/↓ day ±week · T today · N week numbers.
// Events: shown only if `khal` is installed (no accounts, no network).
Item {
  id: root
  focus: true
  property string hint: "←/→ month · PgUp/PgDn year · ↑/↓ week · T today · N week numbers · Esc close"

  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()        // 0-11
  property date selected: new Date()
  property bool weekNumbers: false
  property bool hasKhal: false
  property var eventDays: ({})                      // "YYYY-MM-DD" -> true
  property string dayEvents: ""

  readonly property var loc: Qt.locale()
  readonly property int firstDow: loc.firstDayOfWeek % 7    // 0 = Sunday (Qt reports Sunday as 7 in some builds)
  readonly property var monthNames: [0,1,2,3,4,5,6,7,8,9,10,11].map(function (m) { return loc.monthName(m, Locale.LongFormat) })

  function iso(d) { return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2) }
  // ISO 8601 week number.
  function weekOf(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    var day = t.getUTCDay() || 7
    t.setUTCDate(t.getUTCDate() + 4 - day)
    var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
    return Math.ceil(((t - y0) / 86400000 + 1) / 7)
  }
  // 42 cells: leading days of the previous month, the month, trailing days.
  readonly property var cells: {
    var first = new Date(year, month, 1)
    var offset = (first.getDay() - firstDow + 7) % 7
    var out = []
    for (var i = 0; i < 42; i++) {
      var d = new Date(year, month, 1 - offset + i)
      out.push({ date: d, inMonth: d.getMonth() === month })
    }
    return out
  }

  function shiftMonth(n) {
    var m = month + n, y = year
    while (m < 0) { m += 12; y-- }
    while (m > 11) { m -= 12; y++ }
    month = m; year = y
    loadEvents()
  }
  function goToday() { var t = new Date(); year = t.getFullYear(); month = t.getMonth(); selected = t; loadEvents() }
  function select(d) { selected = d; if (d.getMonth() !== month || d.getFullYear() !== year) { month = d.getMonth(); year = d.getFullYear(); loadEvents() } loadDay() }

  Keys.onPressed: function (e) {
    if (e.key === Qt.Key_Left || e.key === Qt.Key_H) { shiftMonth(-1); e.accepted = true }
    else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) { shiftMonth(1); e.accepted = true }
    else if (e.key === Qt.Key_PageUp) { year--; loadEvents(); e.accepted = true }
    else if (e.key === Qt.Key_PageDown) { year++; loadEvents(); e.accepted = true }
    else if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
      var d = new Date(selected); d.setDate(d.getDate() + (e.key === Qt.Key_Up ? -7 : 7)); select(d); e.accepted = true }
    else if (e.key === Qt.Key_T) { goToday(); e.accepted = true }
    else if (e.key === Qt.Key_N) { weekNumbers = !weekNumbers; e.accepted = true }
  }

  // ---- header ----
  Text { x: 22; y: 14; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 16; font.bold: true
    text: root.monthNames[root.month] + " " + root.year }
  Row { anchors.right: parent.right; anchors.rightMargin: 18; y: 12; spacing: 6
    Repeater { model: [ { ic: "chevron-left", d: -1 }, { ic: "chevron-right", d: 1 } ]
      delegate: Rectangle { required property var modelData; width: 30; height: 30; radius: 15; color: Theme.surface
        Icon { anchors.centerIn: parent; name: modelData.ic; size: 16 }
        MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(modelData.d) } } }
  }

  // ---- grid ----
  readonly property real colW: (width - 36 - (weekNumbers ? 28 : 0)) / 7
  Row {
    x: 18 + (root.weekNumbers ? 28 : 0); y: 52
    Repeater { model: 7
      delegate: Text { required property int index
        width: root.colW; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText
        // Locale.dayName: 1 = Monday ... 7 = Sunday
        text: { var dow = (root.firstDow + index) % 7; return root.loc.dayName(dow === 0 ? 7 : dow, Locale.ShortFormat).slice(0, 2) }
        color: Theme.textMuted; font.pixelSize: 11 } }
  }
  Repeater {
    model: root.weekNumbers ? 6 : 0
    delegate: Text { required property int index
      x: 18; y: 74 + index * 34; width: 24; height: 32; verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText; text: root.weekOf(root.cells[index * 7 + 3].date)
      color: Theme.textMuted; font.pixelSize: 10 }
  }
  Grid {
    x: 18 + (root.weekNumbers ? 28 : 0); y: 74
    columns: 7
    Repeater {
      model: root.cells
      delegate: Item {
        required property var modelData
        width: root.colW; height: 34
        readonly property bool today: root.iso(modelData.date) === root.iso(new Date())
        readonly property bool isSel: root.iso(modelData.date) === root.iso(root.selected)
        readonly property bool weekend: modelData.date.getDay() === 0 || modelData.date.getDay() === 6
        Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15
          color: today ? Theme.accent : "transparent"
          border.width: isSel && !today ? 2 : 0; border.color: Theme.text }
        Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: modelData.date.getDate()
          font.pixelSize: 12; font.bold: today
          color: today ? Theme.accentText : (!modelData.inMonth ? Theme.outline : (weekend ? Theme.textMuted : Theme.text)) }
        Rectangle { visible: root.eventDays[root.iso(modelData.date)] === true     // khal event dot
          anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 1
          width: 4; height: 4; radius: 2; color: today ? Theme.accentText : Theme.accent }
        MouseArea { anchors.fill: parent; onClicked: root.select(modelData.date) }
      }
    }
  }
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton
    onWheel: function (w) { root.shiftMonth(w.angleDelta.y > 0 ? -1 : 1) } }

  // ---- events (only if khal exists) ----
  Text { visible: root.hasKhal; x: 22; y: 290; width: root.width - 44; elide: Text.ElideRight; textFormat: Text.PlainText
    text: root.dayEvents !== "" ? root.dayEvents : "No events"; color: Theme.textMuted; font.pixelSize: 12 }

  function loadEvents() {
    if (!hasKhal) return
    var a = new Date(year, month, 1), b = new Date(year, month + 1, 0)
    monthProc.command = ["khal", "list", "--format", "{start-date}", iso(a), iso(b)]
    monthProc.running = true
    loadDay()
  }
  function loadDay() {
    if (!hasKhal) return
    dayProc.command = ["khal", "list", "--format", "{start-time} {title}", iso(selected), iso(selected)]
    dayProc.running = true
  }
  Process { running: true; command: ["bash", "-c", "command -v khal"]
    onExited: function (c) { root.hasKhal = (c === 0); root.loadEvents() } }
  Process { id: monthProc
    stdout: StdioCollector { onStreamFinished: {
      var set = {}; text.split("\n").forEach(function (l) { var m = /^\d{4}-\d{2}-\d{2}/.exec(l.trim()); if (m) set[m[0]] = true })
      root.eventDays = set } } }
  Process { id: dayProc
    stdout: StdioCollector { onStreamFinished: root.dayEvents = text.split("\n").filter(function (l) { return l.trim() !== "" && !/^\d{4}-/.test(l) }).slice(0, 2).join("  ·  ") } }
}
