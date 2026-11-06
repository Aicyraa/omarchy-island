import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Calendar: month grid sized to the weeks it needs (no dead space). Today is
// accent-filled, weekends dimmed, adjacent-month days dimmed but legible, week
// numbers optional (N), first weekday from the locale, "Today" button (T).
// Keys: ←/→ or H/L month · PgUp/PgDn year · ↑/↓ week · T today · N week numbers.
// Events show only if `khal` is installed (no accounts, no network).
WidgetPanel {
  id: root
  preferredWidth: 400
  hint: "←/→ month · PgUp/Dn year · ↑/↓ week · T today · N weeks"

  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()
  property date selected: new Date()
  property bool weekNumbers: false
  property bool hasKhal: false
  property var eventDays: ({})
  property string dayEvents: ""

  readonly property var loc: Qt.locale()
  readonly property int firstDow: loc.firstDayOfWeek % 7
  readonly property var monthNames: [0,1,2,3,4,5,6,7,8,9,10,11].map(function (m) { return loc.monthName(m, Locale.LongFormat) })

  function iso(d) { return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2) }
  function weekOf(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate())), day = t.getUTCDay() || 7
    t.setUTCDate(t.getUTCDate() + 4 - day)
    var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
    return Math.ceil(((t - y0) / 86400000 + 1) / 7)
  }
  readonly property int offset: (new Date(year, month, 1).getDay() - firstDow + 7) % 7
  readonly property int weeks: Math.ceil((offset + new Date(year, month + 1, 0).getDate()) / 7)
  readonly property var cells: {
    var out = []
    for (var i = 0; i < weeks * 7; i++) { var d = new Date(year, month, 1 - offset + i); out.push({ date: d, inMonth: d.getMonth() === month }) }
    return out
  }

  function shiftMonth(n) {
    var m = month + n, y = year
    while (m < 0) { m += 12; y-- }
    while (m > 11) { m -= 12; y++ }
    month = m; year = y; loadEvents()
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

  // ---- header: month title, Today button, month arrows ----
  Item {
    width: parent.width; height: 36
    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 16; font.bold: true
      text: root.monthNames[root.month] + " " + root.year }
    Row { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Rectangle { height: 30; width: todayLabel.implicitWidth + Theme.s16 * 2; radius: 15; color: Theme.surface
        Text { id: todayLabel; anchors.centerIn: parent; textFormat: Text.PlainText; text: "Today  T"; color: Theme.text; font.pixelSize: 12; font.bold: true }
        MouseArea { anchors.fill: parent; onClicked: root.goToday() } }
      Repeater { model: [ { ic: "chevron-left", d: -1 }, { ic: "chevron-right", d: 1 } ]
        delegate: Rectangle { required property var modelData; width: 30; height: 30; radius: 15; color: Theme.surface
          Icon { anchors.centerIn: parent; name: modelData.ic; size: Theme.iconSm }
          MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(modelData.d) } } }
    }
  }

  // ---- weekday header + grid (same column width for both) ----
  readonly property real wkW: weekNumbers ? 26 : 0
  readonly property real colW: (width - 2 * pad - wkW) / 7
  Row {
    x: root.wkW
    Repeater { model: 7
      delegate: Text { required property int index
        width: root.colW; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText
        text: { var dow = (root.firstDow + index) % 7; return root.loc.dayName(dow === 0 ? 7 : dow, Locale.ShortFormat).slice(0, 2) }
        color: Theme.textMuted; font.pixelSize: 11 } }
  }
  Item {
    width: parent.width; height: root.weeks * 34
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton
      onWheel: function (w) { root.shiftMonth(w.angleDelta.y > 0 ? -1 : 1) } }
    Repeater {
      model: root.weekNumbers ? root.weeks : 0
      delegate: Text { required property int index
        y: index * 34; width: 22; height: 34; verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText; text: root.weekOf(root.cells[index * 7 + 3].date); color: Theme.textMuted; font.pixelSize: 10 }
    }
    Grid {
      x: root.wkW; columns: 7
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
            color: today ? Theme.accentText : (!modelData.inMonth ? Theme.textMuted : (weekend ? Theme.textMuted : Theme.text))
            opacity: !modelData.inMonth && !today ? 0.75 : 1 }
          Rectangle { visible: root.eventDays[root.iso(modelData.date)] === true
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 1
            width: 4; height: 4; radius: 2; color: today ? Theme.accentText : Theme.accentInk }
          MouseArea { anchors.fill: parent; onClicked: root.select(modelData.date) }
        }
      }
    }
  }

  // ---- events: not reserved at all unless khal exists ----
  Text { visible: root.hasKhal; width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
    text: root.dayEvents !== "" ? root.dayEvents : "No events"; color: Theme.textMuted; font.pixelSize: 12 }

  function loadEvents() {
    if (!hasKhal) return
    var a = new Date(year, month, 1), b = new Date(year, month + 1, 0)
    monthProc.command = ["khal", "list", "--format", "{start-date}", iso(a), iso(b)]; monthProc.running = true
    loadDay()
  }
  function loadDay() {
    if (!hasKhal) return
    dayProc.command = ["khal", "list", "--format", "{start-time} {title}", iso(selected), iso(selected)]; dayProc.running = true
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
