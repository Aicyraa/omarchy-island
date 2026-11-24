pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Core"
import "../Core/Visuals"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 660
    scrollTarget: cityList
    readonly property bool wantsKeyboard: searching
    readonly property bool capturesEscape: searching
    hint: searching
        ? qsTr("Type to search · ↑/↓ choose · Enter add · Esc cancel")
        : qsTr("↑/↓ select · A add · D remove · Esc close")

    readonly property string file: Quickshell.env("HOME") + "/.local/state/island/world-clock.json"
    property var zones: ["Local", "UTC", "America/New_York", "Europe/London", "Asia/Tokyo", "Australia/Sydney"]
    property var rows: []
    property int sel: 0
    property bool use24h: true
    property string localZone: ""
    property var cityMap: ({})

    property bool searching: false
    property string query: ""
    property var allZones: []
    property int pick: 0

    dataLoading: rows.length === 0

    readonly property var sunMarkers: {
        const out = []
        rows.forEach((r, i) => {
            const z = r.zone === "Local" ? localZone : r.zone
            const c = cityMap[z]
            if (c)
                out.push({ lat: c[0], lon: c[1], sel: i === sel })
        })
        return out
    }

    readonly property real focusLon: {
        const r = rows[sel]
        if (!r)
            return 0
        const c = cityMap[r.zone === "Local" ? localZone : r.zone]
        return c ? c[1] : 0
    }

    readonly property var matches: {
        const q = query.toLowerCase().replace(/ /g, "_")
        const res = []
        for (let i = 0; i < allZones.length; i++) {
            const s = q === "" ? 0 : score(allZones[i], q)
            if (s >= 0)
                res.push({ z: allZones[i], s: s })
        }
        res.sort((a, b) => b.s - a.s)
        return res.slice(0, 12).map(r => r.z)
    }

    Component.onCompleted: store.reload()

    function isoCoord(t: string): var {
        const m = /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/.exec(t)
        if (!m)
            return null
        const la = parseInt(m[2], 10) + parseInt(m[3], 10) / 60 + (m[4] ? parseInt(m[4], 10) / 3600 : 0)
        const lo = parseInt(m[6], 10) + parseInt(m[7], 10) / 60 + (m[8] ? parseInt(m[8], 10) / 3600 : 0)
        return [m[1] === "-" ? -la : la, m[5] === "-" ? -lo : lo]
    }

    function cityOf(z: string): string {
        return z === "Local" ? "Local" : (z === "UTC" ? "UTC" : z.split("/").pop().replace(/_/g, " "))
    }

    function offMin(z: string): int {
        const s = z[0] === "-" ? -1 : 1
        return s * (parseInt(z.slice(1, 3), 10) * 60 + parseInt(z.slice(3, 5), 10))
    }

    function save(): void {
        store.setText(JSON.stringify({ zones: zones }))
    }

    function refresh(): void {
        const safe = zones.filter(z => z === "Local" || /^[A-Za-z0-9_+\-\/]+$/.test(z))
        const script = "for z in " + safe.map(z => z === "Local" ? "Local" : "'" + z + "'").join(" ")
            + "; do if [ \"$z\" = Local ]; then d=$(date '+%z %a %H %M %Y%m%d'); else d=$(TZ=$z date '+%z %a %H %M %Y%m%d'); fi; echo \"$z $d\"; done; echo \"LOCAL $(date '+%z %a %H %M %Y%m%d')\""
        clockProc.command = ["bash", "-c", script]
        clockProc.running = true
    }

    function openSearch(): void {
        query = ""
        pick = 0
        searching = true
        if (allZones.length === 0)
            tzList.running = true
        Qt.callLater(() => {
            tzInput.text = ""
            tzInput.focusInput()
        })
    }

    function closeSearch(): void {
        searching = false
        tzInput.text = ""
        query = ""
        root.forceActiveFocus()
    }

    function score(name: string, q: string): int {
        const n = name.toLowerCase()
        let qi = 0
        let sc = 0
        let last = -2
        for (let i = 0; i < n.length && qi < q.length; i++) {
            if (n[i] === q[qi]) {
                sc += (i === last + 1) ? 3 : 1
                last = i
                qi++
            }
        }
        return qi === q.length ? sc : -1
    }

    function addZone(z: string): void {
        if (z && zones.indexOf(z) < 0 && zones.length < 12) {
            zones = zones.concat([z])
            save()
            refresh()
        }
        closeSearch()
    }

    function removeZone(z: string): void {
        if (!z || z === "Local")
            return
        zones = zones.filter(x => x !== z)
        save()
        refresh()
    }

    FileView {
        path: Qt.resolvedUrl("../../assets/cities.json").toString().replace("file://", "")
        printErrors: false
        onLoaded: {
            try {
                const m = Object.assign({}, root.cityMap)
                JSON.parse(text()).forEach(c => { m[c[1]] = [c[2], c[3]] })
                root.cityMap = m
            } catch (e) {}
        }
    }

    FileView {
        path: "/usr/share/zoneinfo/zone.tab"
        printErrors: false
        onLoaded: {
            const m = Object.assign({}, root.cityMap)
            text().split("\n").forEach(l => {
                if (!l || l[0] === "#")
                    return
                const f = l.split("\t")
                const c = root.isoCoord(f[1])
                if (c && !m[f[2]])
                    m[f[2]] = c
            })
            root.cityMap = m
        }
    }

    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const z = JSON.parse(text()).zones
                if (Array.isArray(z) && z.length) {
                    root.zones = z.slice(0, 12).filter(s => typeof s === "string" && s.length < 64)
                }
            } catch (e) {}
            root.refresh()
        }
        onLoadFailed: root.refresh()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
        printErrors: false
        onLoaded: {
            const m = /"format"\s*:\s*"([^"]*)"/.exec(text())
            if (m)
                root.use24h = !(/[hA]/.test(m[1]) && !/H/.test(m[1]))
        }
    }

    Process {
        running: true
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        stdout: StdioCollector { onStreamFinished: root.localZone = text.trim() }
    }

    Process {
        id: tzList
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: root.allZones = text.trim().split("\n") }
    }

    Process {
        id: clockProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                let local = null
                const out = []
                lines.forEach(l => {
                    const p = l.split(" ")
                    if (p[0] === "LOCAL")
                        local = p
                })
                if (!local)
                    return
                lines.forEach(l => {
                    const p = l.split(" ")
                    if (p[0] === "LOCAL" || p.length < 6)
                        return
                    const diff = (root.offMin(p[1]) - root.offMin(local[1])) / 60
                    const h = parseInt(p[3], 10)
                    const m = parseInt(p[4], 10)
                    const t = root.use24h
                        ? p[3] + ":" + p[4]
                        : ((h % 12) || 12) + ":" + p[4] + (h < 12 ? " AM" : " PM")
                    out.push({
                        zone: p[0],
                        city: root.cityOf(p[0]),
                        time: t,
                        day: p[2] !== local[2] ? p[2] : "",
                        offset: diff === 0 ? "UTC" + (p[1].slice(0, 3)) : (diff > 0 ? "+" : "−") + Math.abs(diff) + "h",
                        night: h < 6 || h >= 18,
                        hour: h + m / 60
                    })
                })
                root.rows = out
                root.sel = Math.min(root.sel, Math.max(0, out.length - 1))
            }
        }
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
    }

    Keys.onPressed: event => {
        if (root.searching) {
            if (event.key === Qt.Key_Escape) {
                IslandState.touch(true)
                root.closeSearch()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                IslandState.touch(true)
                root.pick = Math.min(root.pick + 1, Math.max(0, root.matches.length - 1))
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                IslandState.touch(true)
                root.pick = Math.max(root.pick - 1, 0)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                IslandState.touch(true)
                if (root.matches[root.pick])
                    root.addZone(root.matches[root.pick])
                event.accepted = true
            }
            return
        }
        if (event.key === Qt.Key_Down) {
            IslandState.touch(true)
            root.sel = Math.min(root.sel + 1, Math.max(0, root.rows.length - 1))
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            IslandState.touch(true)
            root.sel = Math.max(root.sel - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_A) {
            IslandState.touch(true)
            root.openSearch()
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            IslandState.touch(true)
            const r = root.rows[root.sel]
            if (r)
                root.removeZone(r.zone)
            event.accepted = true
        }
    }

    RowLayout {
        width: parent.width
        spacing: Tokens.space.lg

        // Left: Globe hero + sun/moon context
        Card {
            Layout.preferredWidth: Tokens.px(208)
            Layout.alignment: Qt.AlignVCenter
            horizontalPadding: Tokens.space.lg
            verticalPadding: Tokens.space.lg
            implicitHeight: globeCol.implicitHeight + verticalPadding * 2

            ColumnLayout {
                id: globeCol

                width: parent.width
                spacing: Tokens.space.sm

                GlobeView {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Tokens.px(160)
                    Layout.preferredHeight: Tokens.px(160)
                    markers: root.sunMarkers
                    focusLon: root.focusLon
                }

                TextLabel {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    role: "subtitle"
                    font.weight: Font.Medium
                    text: root.rows[root.sel] ? root.rows[root.sel].city : ""
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.space.xs

                    Icon {
                        readonly property bool isNight: root.rows[root.sel] ? root.rows[root.sel].night : false
                        icon: isNight ? "moon" : "sun"
                        size: Tokens.size.iconSm
                        tone: isNight ? "muted" : "warning"
                    }

                    TextLabel {
                        role: "sm"
                        tabular: true
                        tone: "muted"
                        text: root.rows[root.sel]
                            ? (root.rows[root.sel].time + (root.rows[root.sel].night ? qsTr(" · Night") : qsTr(" · Day")))
                            : ""
                    }
                }

                Button {
                    Layout.fillWidth: true
                    visible: !root.searching
                    text: qsTr("Add city")
                    icon: "plus"
                    size: "sm"
                    variant: "secondary"
                    accessibleLabel: qsTr("Add city timezone")
                    onClicked: root.openSearch()
                }
            }
        }

        // Right: search + city list
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.space.sm

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xs

                TextField {
                    id: tzInput

                    Layout.fillWidth: true
                    icon: "search"
                    placeholderText: qsTr("Search time zones…")
                    accessibleLabel: qsTr("Search time zones")
                    onTextChanged: {
                        root.query = text
                        root.pick = 0
                        if (text !== "" && !root.searching) {
                            root.searching = true
                            if (root.allZones.length === 0)
                                tzList.running = true
                        }
                    }
                    onAccepted: {
                        if (root.searching && root.matches[root.pick])
                            root.addZone(root.matches[root.pick])
                    }
                    onCleared: root.closeSearch()
                }

                Button {
                    visible: root.searching
                    icon: "close"
                    size: "md"
                    variant: "ghost"
                    accessibleLabel: qsTr("Cancel search")
                    onClicked: root.closeSearch()
                }
            }

            ListView {
                id: cityList

                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.px(250)
                clip: true
                spacing: Tokens.space.xs
                boundsBehavior: Flickable.StopAtBounds
                model: root.searching && root.query !== "" ? root.matches : root.rows

                delegate: Component {
                    Loader {
                        required property var modelData
                        required property int index

                        width: cityList.width
                        sourceComponent: root.searching && root.query !== "" ? searchRowComp : pinnedRowComp

                        Component {
                            id: searchRowComp

                            ListRow {
                                width: cityList.width
                                icon: "globe"
                                title: String(modelData)
                                selected: root.pick === index
                                onClicked: root.addZone(String(modelData))
                            }
                        }

                        Component {
                            id: pinnedRowComp

                            Surface {
                                readonly property var row: modelData
                                readonly property bool isSel: root.sel === index

                                width: cityList.width
                                role: isSel ? "elevated" : "card"
                                radius: Tokens.radius.sm
                                horizontalPadding: Tokens.space.md
                                verticalPadding: Tokens.space.sm
                                implicitHeight: cityRow.implicitHeight + verticalPadding * 2
                                border.color: isSel ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

                                RowLayout {
                                    id: cityRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: Tokens.space.sm

                                    Icon {
                                        icon: row.night ? "moon" : "sun"
                                        size: Tokens.size.iconMd
                                        tone: row.night ? "muted" : "warning"
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        TextLabel {
                                            Layout.fillWidth: true
                                            role: "body"
                                            font.weight: Font.Medium
                                            text: row.city ?? ""
                                        }

                                        TextLabel {
                                            visible: (row.day ?? "") !== ""
                                            role: "caption"
                                            tone: "muted"
                                            text: row.day ?? ""
                                        }
                                    }

                                    Badge {
                                        text: row.offset ?? ""
                                        tone: "neutral"
                                    }

                                    TextLabel {
                                        role: "subtitle"
                                        tabular: true
                                        font.weight: Font.Medium
                                        text: row.time ?? ""
                                    }

                                    Button {
                                        visible: (row.zone ?? "Local") !== "Local"
                                        icon: "close"
                                        size: "sm"
                                        variant: "ghost"
                                        accessibleLabel: qsTr("Remove city")
                                        onClicked: root.removeZone(row.zone)
                                    }
                                }

                                TapHandler {
                                    onTapped: root.sel = index
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
