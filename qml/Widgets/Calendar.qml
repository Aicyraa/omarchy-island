pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Core"
import "../Core/Visuals"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 600
    scrollTarget: remList
    hint: qsTr("←/→ month · PgUp/Dn year · ↑/↓ week · T today · N weeks · Esc close")

    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property date selected: new Date()
    property bool weekNumbers: false
    property bool hasKhal: false
    property var eventDays: ({})
    property string dayEvents: ""
    property var reminders: []

    readonly property var loc: Qt.locale()
    readonly property int firstDow: loc.firstDayOfWeek % 7
    readonly property var monthNames: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map(m => loc.monthName(m, Locale.LongFormat))
    readonly property int offset: (new Date(year, month, 1).getDay() - firstDow + 7) % 7
    readonly property int weeks: Math.ceil((offset + new Date(year, month + 1, 0).getDate()) / 7)
    readonly property var cells: {
        const out = []
        for (let i = 0; i < weeks * 7; i++) {
            const d = new Date(year, month, 1 - offset + i)
            out.push({ date: d, inMonth: d.getMonth() === month })
        }
        return out
    }

    Component.onCompleted: loadReminders()

    function iso(d: date): string {
        return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2)
    }

    function weekOf(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - day)
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }

    function loadReminders(): void {
        if (!remProc.running)
            remProc.running = true
    }

    function addReminder(min: int, message: string): void {
        const args = ["omarchy-reminder", String(Math.max(1, min))]
        if (message && message.trim() !== "")
            args.push(message.trim())
        Cmd.run(args)
        remRefresh.restart()
    }

    function submitQuickReminder(): void {
        const raw = quickInput.text.trim()
        if (raw === "")
            return
        const m = /^(\d+)\s*[mM]?\s*(.*)$/.exec(raw)
        if (m) {
            const mins = Math.max(1, parseInt(m[1], 10))
            addReminder(mins, m[2])
        } else {
            addReminder(15, raw)
        }
        quickInput.text = ""
    }

    function cancelReminder(timer: string): void {
        if (/^omarchy-reminder-[A-Za-z0-9._@:\-]+\.timer$/.test(timer)) {
            Cmd.run(["systemctl", "--user", "stop", timer])
            remRefresh.restart()
        }
    }

    function clearReminders(): void {
        Cmd.run(["omarchy-reminder", "clear"])
        remRefresh.restart()
    }

    function shiftMonth(n: int): void {
        let m = month + n
        let y = year
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        month = m
        year = y
        loadEvents()
    }

    function goToday(): void {
        const t = new Date()
        year = t.getFullYear()
        month = t.getMonth()
        selected = t
        loadEvents()
    }

    function select(d: date): void {
        selected = d
        if (d.getMonth() !== month || d.getFullYear() !== year) {
            month = d.getMonth()
            year = d.getFullYear()
            loadEvents()
        }
        loadDay()
    }

    function loadEvents(): void {
        if (!hasKhal)
            return
        const a = new Date(year, month, 1)
        const b = new Date(year, month + 1, 0)
        monthProc.command = ["khal", "list", "--format", "{start-date}", iso(a), iso(b)]
        monthProc.running = true
        loadDay()
    }

    function loadDay(): void {
        if (!hasKhal)
            return
        dayProc.command = ["khal", "list", "--format", "{start-time} {title}", iso(selected), iso(selected)]
        dayProc.running = true
    }

    Timer { id: remRefresh; interval: 700; onTriggered: root.loadReminders() }
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.loadReminders() }

    Process {
        id: remProc
        command: ["omarchy-reminder", "show", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.reminders = JSON.parse(text).reminders || []
                } catch (e) {
                    root.reminders = []
                }
            }
        }
    }

    Process {
        running: true
        command: ["bash", "-c", "command -v khal"]
        onExited: code => {
            root.hasKhal = (code === 0)
            root.loadEvents()
        }
    }

    Process {
        id: monthProc
        stdout: StdioCollector {
            onStreamFinished: {
                const set = {}
                text.split("\n").forEach(l => {
                    const m = /^\d{4}-\d{2}-\d{2}/.exec(l.trim())
                    if (m)
                        set[m[0]] = true
                })
                root.eventDays = set
            }
        }
    }

    Process {
        id: dayProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.dayEvents = text.split("\n")
                    .filter(l => l.trim() !== "" && !/^\d{4}-/.test(l))
                    .slice(0, 2)
                    .join("  ·  ")
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            IslandState.touch(true)
            root.shiftMonth(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            IslandState.touch(true)
            root.shiftMonth(1)
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            IslandState.touch(true)
            root.year--
            root.loadEvents()
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            IslandState.touch(true)
            root.year++
            root.loadEvents()
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            IslandState.touch(true)
            const d = new Date(root.selected)
            d.setDate(d.getDate() + (event.key === Qt.Key_Up ? -7 : 7))
            root.select(d)
            event.accepted = true
        } else if (event.key === Qt.Key_T) {
            IslandState.touch(true)
            root.goToday()
            event.accepted = true
        } else if (event.key === Qt.Key_N) {
            IslandState.touch(true)
            root.weekNumbers = !root.weekNumbers
            event.accepted = true
        }
    }

    RowLayout {
        width: parent.width
        spacing: Tokens.space.md

        // Left dominant column: month grid
        Card {
            Layout.fillWidth: true
            Layout.preferredWidth: Tokens.px(320)
            Layout.alignment: Qt.AlignTop
            horizontalPadding: Tokens.space.lg
            verticalPadding: Tokens.space.lg
            implicitHeight: calCol.implicitHeight + verticalPadding * 2

            ColumnLayout {
                id: calCol

                width: parent.width
                spacing: Tokens.space.sm

                // Month header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "subtitle"
                        font.weight: Font.Medium
                        text: root.monthNames[root.month] + " " + root.year
                    }

                    Button {
                        icon: "chevron-left"
                        size: "sm"
                        variant: "secondary"
                        accessibleLabel: qsTr("Previous month")
                        onClicked: root.shiftMonth(-1)
                    }

                    Button {
                        text: qsTr("Today")
                        size: "sm"
                        variant: "secondary"
                        accessibleLabel: qsTr("Jump to today")
                        onClicked: root.goToday()
                    }

                    Button {
                        icon: "chevron-right"
                        size: "sm"
                        variant: "secondary"
                        accessibleLabel: qsTr("Next month")
                        onClicked: root.shiftMonth(1)
                    }
                }

                // Weekday header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Item {
                        visible: root.weekNumbers
                        Layout.preferredWidth: Tokens.px(24)
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 0

                        Repeater {
                            model: 7

                            TextLabel {
                                required property int index

                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                role: "caption"
                                tone: "muted"
                                font.weight: Font.Medium
                                text: {
                                    const dow = (root.firstDow + index) % 7
                                    return root.loc.dayName(dow === 0 ? 7 : dow, Locale.ShortFormat).slice(0, 2)
                                }
                            }
                        }
                    }
                }

                // Day grid
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    ColumnLayout {
                        visible: root.weekNumbers
                        Layout.preferredWidth: Tokens.px(24)
                        spacing: 0

                        Repeater {
                            model: root.weekNumbers ? root.weeks : 0

                            TextLabel {
                                required property int index

                                Layout.preferredHeight: Tokens.px(34)
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                role: "caption"
                                tabular: true
                                tone: "muted"
                                text: String(root.weekOf(root.cells[index * 7 + 3].date))
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 0

                        WheelHandler {
                            onWheel: event => root.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
                        }

                        Repeater {
                            model: root.cells

                            Item {
                                id: dayCell

                                required property var modelData
                                readonly property bool isToday: root.iso(modelData.date) === root.iso(new Date())
                                readonly property bool isSel: root.iso(modelData.date) === root.iso(root.selected)
                                readonly property bool hasDot: root.eventDays[root.iso(modelData.date)] === true
                                    || (isToday && root.reminders.length > 0)

                                Layout.fillWidth: true
                                Layout.preferredHeight: Tokens.px(34)
                                activeFocusOnTab: modelData.inMonth
                                Accessible.role: Accessible.Button
                                Accessible.name: Qt.formatDate(modelData.date, "dddd d MMMM yyyy")

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Tokens.px(28)
                                    height: Tokens.px(28)
                                    radius: Tokens.radius.pill
                                    color: {
                                        if (dayCell.isToday)
                                            return dayHover.hovered ? Tokens.color.accentHover : Tokens.color.accent
                                        if (dayCell.isSel)
                                            return Tokens.color.accentMuted
                                        if (dayHover.hovered)
                                            return Tokens.veilHoverOf(Tokens.surfaceStyle)
                                        return "transparent"
                                    }
                                    border.width: dayCell.isSel && !dayCell.isToday ? Tokens.hairlineWidth : 0
                                    border.color: Tokens.color.accent
                                }

                                TextLabel {
                                    anchors.centerIn: parent
                                    role: "body"
                                    tabular: true
                                    font.weight: dayCell.isToday || dayCell.isSel ? Font.Medium : Font.Normal
                                    tone: dayCell.isToday ? "onAccent" : (dayCell.modelData.inMonth ? "primary" : "muted")
                                    opacity: !dayCell.modelData.inMonth && !dayCell.isToday ? 0.5 : 1.0
                                    text: String(dayCell.modelData.date.getDate())
                                }

                                Rectangle {
                                    visible: dayCell.hasDot
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: Tokens.px(1)
                                    width: Tokens.px(4)
                                    height: Tokens.px(4)
                                    radius: Tokens.radius.pill
                                    color: dayCell.isToday ? Tokens.color.onAccent : Tokens.color.accent
                                }

                                FocusRing {
                                    active: dayCell.activeFocus
                                    ringRadius: Tokens.radius.pill
                                }

                                HoverHandler {
                                    id: dayHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: root.select(dayCell.modelData.date)
                                }

                                Keys.onReturnPressed: root.select(dayCell.modelData.date)
                                Keys.onSpacePressed: root.select(dayCell.modelData.date)
                            }
                        }
                    }
                }
            }
        }

        // Right column: Selected Day + Omarchy Reminders
        ColumnLayout {
            Layout.preferredWidth: Tokens.px(228)
            Layout.fillHeight: true
            spacing: Tokens.space.sm

            Card {
                Layout.fillWidth: true
                horizontalPadding: Tokens.space.lg
                verticalPadding: Tokens.space.md
                implicitHeight: daySummaryCol.implicitHeight + verticalPadding * 2

                ColumnLayout {
                    id: daySummaryCol

                    width: parent.width
                    spacing: Tokens.space.xxs

                    TextLabel {
                        role: "caption"
                        tone: "accent"
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        text: Qt.formatDate(root.selected, "dddd")
                    }

                    RowLayout {
                        spacing: Tokens.space.sm

                        TextLabel {
                            role: "h1"
                            tabular: true
                            text: String(root.selected.getDate())
                        }

                        TextLabel {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: Tokens.space.xxs
                            role: "sm"
                            tone: "muted"
                            text: root.monthNames[root.selected.getMonth()].slice(0, 3) + " " + root.selected.getFullYear()
                        }
                    }

                    TextLabel {
                        visible: root.hasKhal
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        text: root.dayEvents !== "" ? root.dayEvents : qsTr("No events scheduled")
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalPadding: Tokens.space.lg
                verticalPadding: Tokens.space.md
                implicitHeight: remCol.implicitHeight + verticalPadding * 2

                ColumnLayout {
                    id: remCol

                    width: parent.width
                    spacing: Tokens.space.sm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        TextLabel {
                            role: "sm"
                            font.weight: Font.Medium
                            tone: "secondary"
                            text: qsTr("Reminders")
                        }

                        Badge {
                            visible: root.reminders.length > 0
                            text: String(root.reminders.length)
                            tone: "accent"
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            visible: root.reminders.length > 0
                            text: qsTr("Clear")
                            size: "sm"
                            variant: "ghost"
                            accessibleLabel: qsTr("Clear all reminders")
                            onClicked: root.clearReminders()
                        }
                    }

                    TextField {
                        id: quickInput

                        Layout.fillWidth: true
                        icon: "plus"
                        placeholderText: qsTr("15m Take a break…")
                        accessibleLabel: qsTr("Add reminder")
                        onAccepted: root.submitQuickReminder()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        Repeater {
                            model: [
                                { l: "+5m", m: 5 },
                                { l: "+15m", m: 15 },
                                { l: "+30m", m: 30 },
                                { l: "+1h", m: 60 }
                            ]

                            Button {
                                required property var modelData

                                Layout.fillWidth: true
                                text: modelData.l
                                size: "sm"
                                variant: "secondary"
                                onClicked: root.addReminder(modelData.m, "")
                            }
                        }
                    }

                    ListView {
                        id: remList

                        Layout.fillWidth: true
                        Layout.preferredHeight: root.reminders.length > 0
                            ? Math.min(Tokens.px(124), contentHeight)
                            : 0
                        visible: root.reminders.length > 0
                        clip: true
                        spacing: Tokens.space.xs
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.reminders

                        delegate: Surface {
                            id: remCard

                            required property var modelData

                            width: remList.width
                            role: "elevated"
                            radius: Tokens.radius.sm
                            horizontalPadding: Tokens.space.sm
                            verticalPadding: Tokens.space.xs
                            implicitHeight: remRow.implicitHeight + verticalPadding * 2

                            RowLayout {
                                id: remRow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: Tokens.space.sm

                                Icon {
                                    icon: "bell"
                                    size: Tokens.size.iconSm
                                    tone: "accent"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    TextLabel {
                                        Layout.fillWidth: true
                                        role: "sm"
                                        font.weight: Font.Medium
                                        text: remCard.modelData.label ?? ""
                                    }

                                    TextLabel {
                                        Layout.fillWidth: true
                                        role: "caption"
                                        tone: "muted"
                                        tabular: true
                                        text: qsTr("in %1").arg(remCard.modelData.remaining ?? "")
                                    }
                                }

                                Button {
                                    icon: "check"
                                    size: "sm"
                                    variant: "ghost"
                                    accessibleLabel: qsTr("Complete reminder")
                                    onClicked: root.cancelReminder(remCard.modelData.timer ?? "")
                                }
                            }
                        }
                    }

                    TextLabel {
                        visible: root.reminders.length === 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        role: "caption"
                        tone: "muted"
                        text: qsTr("No active reminders")
                    }
                }
            }
        }
    }
}
