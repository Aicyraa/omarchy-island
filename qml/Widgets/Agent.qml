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

    preferredWidth: 640
    scrollTarget: agentList
    hint: qsTr("R refresh · Esc close")
    dataLoading: !AgentUsage.loaded
    compact: !loading && agents.length === 0

    readonly property var agents: AgentUsage.agents || []
    readonly property bool loading: !AgentUsage.loaded
    readonly property real todayTokens: agents.reduce(function (s, a) { return s + (Number(a.today) || 0) }, 0)
    readonly property int activeCount: agents.filter(function (a) { return !!a.isRunning }).length
    readonly property int gridRows: Math.ceil(agents.length / 2)
    property real now: Date.now()

    readonly property string headerDetail: {
        if (root.loading)
            return qsTr("Reading harness usage…")
        if (root.agents.length === 0)
            return qsTr("No active harnesses")
        const parts = [root.fmt(root.todayTokens) + " " + qsTr("tokens today")]
        if (root.activeCount > 0)
            parts.push(qsTr("%1 active").arg(root.activeCount))
        if (AgentUsage.fetchedAt > 0)
            parts.push(root.ago(AgentUsage.fetchedAt))
        return parts.join(" · ")
    }

    function ago(ms: real): string {
        const m = Math.round((root.now - ms) / 60000)
        if (m < 1)
            return qsTr("just now")
        if (m < 60)
            return m + "m ago"
        return Math.round(m / 60) + "h ago"
    }

    function glyph(id: string): string {
        switch (id) {
        case "opencode": return "terminal"
        case "agy":      return "sparkles"
        case "claude":   return "zap"
        case "codex":    return "cpu"
        case "copilot":  return "activity"
        case "cursor":   return "layers"
        default:         return "sparkles"
        }
    }

    function resets(iso: string): string {
        const t = Date.parse(iso)
        if (isNaN(t))
            return ""
        const m = Math.max(0, Math.round((t - root.now) / 60000))
        if (m < 60)
            return qsTr("resets %1m").arg(m)
        if (m < 1440)
            return qsTr("resets %1h").arg(Math.round(m / 60))
        return qsTr("resets %1d").arg(Math.round(m / 1440))
    }

    function fmt(n: real): string {
        const v = Number(n) || 0
        if (v >= 1e9) return (v / 1e9).toFixed(v >= 1e10 ? 0 : 1) + "B"
        if (v >= 1e6) return (v / 1e6).toFixed(v >= 1e7 ? 0 : 1) + "M"
        if (v >= 1e3) return (v / 1e3).toFixed(v >= 1e4 ? 0 : 1) + "K"
        return String(Math.round(v))
    }

    function fmtTokens(n: real): string {
        return root.fmt(n)
    }

    function mainLimit(agent: var): var {
        if (agent && agent.limits && agent.limits.length > 0)
            return agent.limits[0]
        return null
    }

    function hasQuota(agent: var): bool {
        const lim = mainLimit(agent)
        return lim !== null && typeof lim.percent === "number"
    }

    function cardValue(agent: var): string {
        if (hasQuota(agent))
            return String(Math.round(Number(mainLimit(agent).percent) * 100))
        if ((Number(agent.today) || 0) > 0)
            return fmt(agent.today)
        if ((Number(agent.totalPrompts) || 0) > 0)
            return String(agent.totalPrompts)
        return "0"
    }

    function cardUnit(agent: var): string {
        if (hasQuota(agent))
            return "%"
        if ((Number(agent.today) || 0) > 0)
            return qsTr("tokens")
        if ((Number(agent.totalPrompts) || 0) > 0)
            return qsTr("prompts")
        return qsTr("tokens")
    }

    function barProgress(agent: var): real {
        if (hasQuota(agent))
            return Math.max(0, Math.min(1, Number(mainLimit(agent).percent) || 0))
        if (root.todayTokens > 0 && (Number(agent.today) || 0) > 0)
            return Math.max(0.05, Math.min(1, Number(agent.today) / root.todayTokens))
        if ((Number(agent.totalPrompts) || 0) > 0)
            return Math.min(1, Number(agent.totalPrompts) / 100)
        return 0
    }

    function barLeftText(agent: var): string {
        if (hasQuota(agent)) {
            const lim = mainLimit(agent)
            return String(lim.label || qsTr("Window"))
        }
        const m = String(agent.topModel || "")
        if (m !== "")
            return m.replace(/^claude-/, "").replace(/^gpt-/, "GPT-").slice(0, 22)
        return agent.isDefault ? qsTr("Default harness") : qsTr("Local harness")
    }

    function barRightText(agent: var): string {
        if (hasQuota(agent)) {
            const lim = mainLimit(agent)
            const r = resets(String(lim.resetsAt || ""))
            if (r !== "")
                return r
            if ((Number(agent.today) || 0) > 0)
                return fmtTokens(agent.today) + " " + qsTr("today")
            return ""
        }
        const inT = Number(agent.inT) || 0
        const outT = Number(agent.outT) || 0
        if (inT + outT > 0)
            return fmtTokens(outT) + " out · " + fmtTokens(inT) + " in"
        if ((Number(agent.sessions) || 0) > 0)
            return qsTr("%1 sessions").arg(agent.sessions)
        return ""
    }

    function cardSubtext(agent: var): string {
        const parts = []
        if ((Number(agent.today) || 0) > 0 && hasQuota(agent))
            parts.push(fmtTokens(agent.today) + " " + qsTr("today"))
        if ((Number(agent.week) || 0) > 0)
            parts.push(fmtTokens(agent.week) + " / 7d")
        if ((Number(agent.cacheT) || 0) > 0)
            parts.push(fmtTokens(agent.cacheT) + " " + qsTr("cached"))
        return parts.join(" · ")
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }

    Keys.onPressed: function (e) {
        if (e.key === Qt.Key_R) {
            AgentUsage.collect(true)
            e.accepted = true
        }
    }

    Component.onCompleted: {
        AgentUsage.watch(true)
        AgentUsage.refresh()
        AgentUsage.collect(false)
    }
    Component.onDestruction: AgentUsage.watch(false)

    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        DetailHeader {
            Layout.fillWidth: true
            title: qsTr("AI Agents")
            icon: "sparkles"
            detail: root.headerDetail
            backable: false
        }

        Button {
            icon: "refresh-cw"
            text: qsTr("Refresh")
            variant: "secondary"
            size: "sm"
            onClicked: AgentUsage.collect(true)
        }
    }

    Card {
        visible: root.loading && root.agents.length === 0
        width: parent.width
        implicitHeight: Tokens.px(88)

        RowLayout {
            anchors.centerIn: parent
            spacing: Tokens.space.md

            LoadingSpinner {
                size: Tokens.size.iconMd
                running: root.loading
            }

            TextLabel {
                role: "sm"
                tone: "muted"
                text: qsTr("Reading harness usage…")
            }
        }
    }

    EmptyState {
        visible: !root.loading && root.agents.length === 0
        width: parent.width
        icon: "sparkles"
        title: qsTr("No AI usage yet")
        description: qsTr("Usage and quota metrics appear once an AI coding harness is active.")
    }

    GridView {
        id: agentList

        visible: root.agents.length > 0
        width: parent.width
        height: Math.min(Tokens.px(320), root.gridRows * cellHeight)
        cellWidth: Tokens.px(294)
        cellHeight: Tokens.px(154)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.agents

        delegate: Item {
            id: agentSlot

            required property var modelData

            width: agentList.cellWidth
            height: agentList.cellHeight

            MetricCard {
                id: agentCard

                width: agentSlot.width - Tokens.space.sm
                height: agentSlot.height - Tokens.space.sm
                horizontalPadding: Tokens.space.lg
                verticalPadding: Tokens.space.md
                compact: true
                icon: root.glyph(String(agentSlot.modelData.id ?? ""))
                label: String(agentSlot.modelData.name ?? "")
                    + (String(agentSlot.modelData.tier ?? "") !== "" ? (" · " + agentSlot.modelData.tier) : "")
                value: root.cardValue(agentSlot.modelData)
                unit: root.cardUnit(agentSlot.modelData)
                delta: agentSlot.modelData.isRunning ? qsTr("Running") : (agentSlot.modelData.isDefault ? qsTr("Default") : "")
                deltaTone: agentSlot.modelData.isRunning ? "success" : "accent"
                subtext: root.cardSubtext(agentSlot.modelData)

                ColumnLayout {
                    width: parent.width
                    spacing: Tokens.space.xs

                    UsageBar {
                        Layout.fillWidth: true
                        segmented: true
                        segments: 14
                        autoThreshold: true
                        progress: root.barProgress(agentSlot.modelData)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.xs

                        TextLabel {
                            Layout.fillWidth: true
                            role: "sm"
                            tone: "muted"
                            text: root.barLeftText(agentSlot.modelData)
                        }

                        TextLabel {
                            role: "sm"
                            tone: "secondary"
                            tabular: true
                            text: root.barRightText(agentSlot.modelData)
                        }
                    }
                }
            }
        }
    }
}
