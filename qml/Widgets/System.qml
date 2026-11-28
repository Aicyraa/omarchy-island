pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 720
    scrollTarget: procList
    hint: qsTr("Esc close")
    dataLoading: !SysInfo.loaded

    readonly property int cpuPct: Math.round(Stats.cpu * 100)
    readonly property int memPct: Math.round(Stats.mem * 100)
    readonly property int cpuWarn: cpuPct >= 85 ? 2 : (cpuPct >= 65 ? 1 : 0)
    readonly property int memWarn: memPct >= 90 ? 2 : (memPct >= 78 ? 1 : 0)
    readonly property int tempWarn: Stats.temp > 80 ? 2 : (Stats.temp > 70 ? 1 : 0)

    readonly property real load1: SysInfo.load1
    readonly property real load5: SysInfo.load5
    readonly property real load15: SysInfo.load15
    readonly property real uptimeSec: SysInfo.uptimeSec
    readonly property real freqMHz: SysInfo.freqMHz
    readonly property int cores: SysInfo.cores
    readonly property real loadRatio: cores > 0 ? Math.min(1, load1 / cores) : 0
    readonly property var procs: SysInfo.procs || []

    readonly property color cpuTint: cpuWarn === 2 ? Tokens.color.danger
        : (cpuWarn === 1 ? Tokens.color.warning : Tokens.color.accent)
    readonly property color memTint: memWarn === 2 ? Tokens.color.danger
        : (memWarn === 1 ? Tokens.color.warning : Tokens.color.accent)

    readonly property string thermalTone: {
        if (Stats.temp > 0)
            return tempWarn === 2 ? "danger" : (tempWarn === 1 ? "warning" : "success")
        return loadRatio >= 0.9 ? "danger" : (loadRatio >= 0.7 ? "warning" : "success")
    }

    readonly property string thermalLabel: {
        if (Stats.temp > 0)
            return tempWarn === 2 ? qsTr("Hot") : (tempWarn === 1 ? qsTr("Warm") : qsTr("Cool"))
        return loadRatio >= 0.9 ? qsTr("High") : (loadRatio >= 0.7 ? qsTr("Busy") : qsTr("Nominal"))
    }

    function bytes(n: real): string {
        let v = Number(n) || 0
        const units = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (v >= 1000 && i < 4) {
            v /= 1000
            i++
        }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i]
    }

    function dur(sec: real): string {
        const d = Math.floor(sec / 86400)
        const h = Math.floor((sec % 86400) / 3600)
        const m = Math.floor((sec % 3600) / 60)
        if (d > 0)
            return d + "d " + h + "h"
        if (h > 0)
            return h + "h " + m + "m"
        return m + "m"
    }

    function killProc(proc: var): void {
        if (!proc)
            return
        const pid = Number(proc.pid ?? 0)
        if (pid > 0) {
            Cmd.run(["kill", String(pid)])
            SysInfo.refresh()
        }
    }

    Component.onCompleted: Stats.sampling = true
    Component.onDestruction: Stats.sampling = false

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: SysInfo.refresh()
    }

    RowLayout {
        width: parent.width
        spacing: Tokens.space.md

        MetricCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            compact: true
            verticalPadding: Tokens.space.md
            label: qsTr("CPU")
            icon: "cpu"
            value: String(root.cpuPct)
            unit: "%"
            delta: root.cpuWarn === 2 ? qsTr("Heavy") : (root.cpuWarn === 1 ? qsTr("Active") : qsTr("Idle"))
            deltaTone: root.cpuWarn === 2 ? "danger" : (root.cpuWarn === 1 ? "warning" : "success")
            subtext: (root.freqMHz > 0 ? (root.freqMHz / 1000).toFixed(2) + " GHz" : "")
                + (root.freqMHz > 0 && root.cores > 0 ? " · " : "")
                + (root.cores > 0 ? qsTr("%1 cores").arg(root.cores) : "")

            Sparkline {
                width: parent.width
                height: Tokens.px(48)
                values: Stats.cpuHist
                minValue: 0
                maxValue: 1
                lineColor: root.cpuTint
            }
        }

        MetricCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            compact: true
            verticalPadding: Tokens.space.md
            label: qsTr("Memory")
            icon: "memory"
            value: Stats.memUsedGb.toFixed(1)
            unit: "/ " + Stats.memTotalGb.toFixed(0) + " GB"
            delta: root.memPct + "%"
            deltaTone: root.memWarn === 2 ? "danger" : (root.memWarn === 1 ? "warning" : "accent")
            subtext: SysInfo.swapTotal > 0
                ? qsTr("Swap %1 / %2").arg(root.bytes(SysInfo.swapUsed)).arg(root.bytes(SysInfo.swapTotal))
                : qsTr("Swap inactive")

            Sparkline {
                width: parent.width
                height: Tokens.px(48)
                values: Stats.memHist
                minValue: 0
                maxValue: 1
                lineColor: root.memTint
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            verticalPadding: Tokens.space.md
            implicitHeight: thermCol.implicitHeight + verticalPadding * 2

            ColumnLayout {
                id: thermCol

                anchors.fill: parent
                spacing: Tokens.space.sm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.sm

                    Icon {
                        size: Tokens.size.iconSm
                        tone: "accent"
                        framed: true
                        icon: "thermometer"
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        text: Stats.temp > 0 ? qsTr("Thermal") : qsTr("Load")
                    }

                    Badge {
                        text: root.thermalLabel
                        tone: root.thermalTone
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xs

                    TextLabel {
                        role: "h2"
                        tabular: true
                        text: Stats.temp > 0 ? (Math.round(Stats.temp) + "°") : root.load1.toFixed(2)
                    }

                    TextLabel {
                        Layout.alignment: Qt.AlignBaseline
                        role: "sm"
                        tone: "muted"
                        text: Stats.temp > 0 ? qsTr("C") : qsTr("1m avg")
                    }

                    Item { Layout.fillWidth: true }
                }

                Item {
                    Layout.fillHeight: true
                }

                TextLabel {
                    visible: root.uptimeSec > 0
                    Layout.fillWidth: true
                    role: "sm"
                    tone: "muted"
                    tabular: true
                    text: qsTr("Up %1").arg(root.dur(root.uptimeSec))
                }

                TextLabel {
                    Layout.fillWidth: true
                    role: "sm"
                    tone: "muted"
                    tabular: true
                    text: Stats.temp > 0
                        ? qsTr("Load %1 · %2 · %3")
                            .arg(root.load1.toFixed(2))
                            .arg(root.load5.toFixed(2))
                            .arg(root.load15.toFixed(2))
                        : qsTr("5m %1 · 15m %2")
                            .arg(root.load5.toFixed(2))
                            .arg(root.load15.toFixed(2))
                }
            }
        }
    }

    Card {
        visible: root.procs.length > 0
        width: parent.width
        implicitHeight: procCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: procCol

            width: parent.width
            spacing: Tokens.space.sm

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.space.md
                Layout.rightMargin: Tokens.space.md
                spacing: Tokens.space.sm

                TextLabel {
                    Layout.fillWidth: true
                    role: "subtitle"
                    font.weight: Font.Medium
                    text: qsTr("Top Processes")
                }

                TextLabel {
                    Layout.preferredWidth: Tokens.px(60)
                    horizontalAlignment: Text.AlignRight
                    role: "caption"
                    tone: "muted"
                    text: qsTr("CPU")
                }

                TextLabel {
                    Layout.preferredWidth: Tokens.px(60)
                    horizontalAlignment: Text.AlignRight
                    role: "caption"
                    tone: "muted"
                    text: qsTr("MEM")
                }

                Item {
                    Layout.preferredWidth: Tokens.px(56)
                }
            }

            ListView {
                id: procList

                Layout.fillWidth: true
                Layout.preferredHeight: root.procs.length > 0
                    ? Math.min(Tokens.px(164), root.procs.length * Tokens.px(42) - Tokens.space.xs)
                    : 0
                clip: true
                spacing: Tokens.space.xs
                boundsBehavior: Flickable.StopAtBounds
                model: root.procs

                delegate: Item {
                    id: procRow

                    required property var modelData
                    required property int index

                    readonly property real cpuVal: Number(procRow.modelData.cpu ?? 0)
                    readonly property real memVal: Number(procRow.modelData.mem ?? 0)
                    readonly property string procName: String(procRow.modelData.name ?? "")

                    width: procList.width
                    height: Tokens.px(38)

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.sm
                        color: rowHover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : "transparent"

                        Behavior on color {
                            enabled: !Tokens.reducedMotion && !Tokens.gameMode
                            ColorAnimation { duration: Tokens.motion.fast }
                        }

                        HoverHandler {
                            id: rowHover
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space.md
                        anchors.rightMargin: Tokens.space.md
                        spacing: Tokens.space.sm

                        TextLabel {
                            Layout.fillWidth: true
                            role: "body"
                            font.weight: Font.Medium
                            text: procRow.procName
                        }

                        TextLabel {
                            Layout.preferredWidth: Tokens.px(60)
                            horizontalAlignment: Text.AlignRight
                            role: "sm"
                            tabular: true
                            tone: procRow.cpuVal >= 50 ? "danger" : (procRow.cpuVal >= 25 ? "warning" : "primary")
                            text: procRow.cpuVal.toFixed(procRow.cpuVal < 10 ? 1 : 0) + "%"
                        }

                        TextLabel {
                            Layout.preferredWidth: Tokens.px(60)
                            horizontalAlignment: Text.AlignRight
                            role: "sm"
                            tone: "muted"
                            tabular: true
                            text: procRow.memVal.toFixed(1) + "%"
                        }

                        Button {
                            Layout.preferredWidth: Tokens.px(56)
                            text: qsTr("Kill")
                            variant: "ghost"
                            size: "sm"
                            accessibleLabel: qsTr("Kill %1").arg(procRow.procName)
                            onClicked: root.killProc(procRow.modelData)
                        }
                    }
                }
            }
        }
    }
}
