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
  Component.onCompleted: loadReminders()
  // Reminders are Omarchy's own (`omarchy-reminder`, systemd timers): listed here, added with one click, cancelled one by one.
  property var reminders: []
  function loadReminders() { if (!remProc.running) remProc.running = true }
  function addReminder(min) { Cmd.run(["omarchy-reminder", String(min)]); remRefresh.restart() }
  function cancelReminder(timer) { if (/^omarchy-reminder-[A-Za-z0-9._@:\-]+\.timer$/.test(timer)) { Cmd.run(["systemctl", "--user", "stop", timer]); remRefresh.restart() } }
  function clearReminders() { Cmd.run(["omarchy-reminder", "clear"]); remRefresh.restart() }
  Timer { id: remRefresh; interval: 700; onTriggered: root.loadReminders() }
  Timer { interval: 30000; repeat: true; running: true; onTriggered: root.loadReminders() }
  Process { id: remProc; command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector { onStreamFinished: { try { root.reminders = (JSON.parse(text).reminders || []).slice(0, 5) } catch (e) { root.reminders = [] } } } }

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
    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; color: Theme.text; font.pixelSize: 16; font.weight: Theme.weightStrong
      text: root.monthNames[root.month] + " " + root.year }
    Row { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Rectangle { antialiasing: true; height: 30; width: todayLabel.implicitWidth + Theme.s16 * 2; radius: 15; color: Theme.surface
        Text { id: todayLabel; anchors.centerIn: parent; textFormat: Text.PlainText; text: "Today"; color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel }
        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goToday() } }
      Repeater { model: [ { ic: "chevron-left", d: -1 }, { ic: "chevron-right", d: 1 } ]
        delegate: Rectangle { antialiasing: true; required property var modelData; width: 30; height: 30; radius: 15; color: Theme.surface
          Icon { anchors.centerIn: parent; name: modelData.ic; size: Theme.iconSm }
          MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.shiftMonth(modelData.d) } } }
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
          Rectangle { antialiasing: true; anchors.centerIn: parent; width: 30; height: 30; radius: 15
            color: today ? (dayArea.containsMouse ? Qt.lighter(Theme.accentFill, 1.12) : Theme.accentFill) : (isSel ? Theme.mix(Theme.pill, Theme.text, 0.20) : (dayArea.containsMouse ? Theme.mix(Theme.pill, Theme.text, 0.12) : "transparent"))
            border.width: 0 }
          Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: modelData.date.getDate()
            font.pixelSize: 12; font.weight: today ? Theme.weightLabel : Font.Normal
            color: today ? Theme.accentText : (!modelData.inMonth ? Theme.textMuted : (weekend ? Theme.textMuted : Theme.text))
            opacity: !modelData.inMonth && !today ? 0.75 : 1 }
          Rectangle { visible: root.eventDays[root.iso(modelData.date)] === true || (today && root.reminders.length > 0)
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 1
            width: 4; height: 4; radius: 2; color: today ? Theme.accentText : Theme.accentInk }
          MouseArea { id: dayArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.select(modelData.date) }
        }
      }
    }
  }

  // ---- reminders ----
  Column {
    width: parent.width; spacing: Theme.s8
    Item { width: parent.width; height: 24
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 12; font.weight: Theme.weightLabel
        text: root.reminders.length > 0 ? "Reminders · " + root.reminders.length : "Reminders" }
      Rectangle { visible: root.reminders.length > 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        height: 24; width: clr.implicitWidth + 20; radius: 12; color: clrArea.containsMouse ? Theme.mix(Theme.surface, Theme.text, 0.12) : Theme.surface
        Text { id: clr; anchors.centerIn: parent; textFormat: Text.PlainText; text: "Clear all"; color: Theme.textMuted; font.pixelSize: 11; font.weight: Theme.weightLabel }
        MouseArea { id: clrArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearReminders() } } }
    Repeater {
      model: root.reminders
      delegate: Rectangle { required property var modelData
        width: parent.width; height: 40; radius: Theme.tileRadius - 4; color: Theme.surface
        Icon { x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; name: "bell"; size: Theme.iconSm; color: Theme.accentInk }
        Column { anchors.left: parent.left; anchors.leftMargin: Theme.s12 + Theme.iconSm + Theme.s8; anchors.right: cancel.left; anchors.rightMargin: Theme.s8
          anchors.verticalCenter: parent.verticalCenter; spacing: 0
          Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.label; color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel }
          Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: "in " + modelData.remaining + " · " + modelData.atTime; color: Theme.textMuted; font.pixelSize: 11 } }
        Rectangle { antialiasing: true; id: cancel; anchors.right: parent.right; anchors.rightMargin: Theme.s8; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 13
          color: xArea.containsMouse ? Theme.mix(Theme.surface, Theme.text, 0.16) : "transparent"
          Icon { anchors.centerIn: parent; name: "x"; size: Theme.iconSm - 2; color: Theme.textMuted }
          MouseArea { id: xArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelReminder(modelData.timer) } }
      }
    }
    Row { spacing: Theme.s8
      Repeater {
        model: [ { l: "+5 min", m: 5 }, { l: "+15 min", m: 15 }, { l: "+30 min", m: 30 }, { l: "+1 hour", m: 60 }, { l: "Custom…", m: 0 } ]
        delegate: Rectangle { required property var modelData
          height: 28; width: (root.width - 2 * root.pad - 4 * Theme.s8) / 5; radius: 14
          color: chipArea.containsMouse ? Theme.mix(Theme.surface, Theme.text, 0.12) : Theme.surface
          Behavior on color { ColorAnimation { duration: 120 } }
          Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: modelData.l; color: Theme.text; font.pixelSize: 11; font.weight: Theme.weightLabel }
          MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (modelData.m > 0) root.addReminder(modelData.m); else { Cmd.run(["omarchy-reminder", "-i"]); IslandState.closeWidget() } } }
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
