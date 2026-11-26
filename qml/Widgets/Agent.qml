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

    preferredWidth: 620
    scrollTarget: agentList
    hint: qsTr("R refresh · Esc close")
    dataLoading: !AgentUsage.loaded
    compact: !loading && agents.length === 0

    readonly property var agents: AgentUsage.agents || []
    readonly property bool loading: !AgentUsage.loaded
    readonly property real todayTokens: agents.reduce(function (s, a) { return s + (Number(a.today) || 0) }, 0)
    readonly property int activeCount: agents.filter(function (a) { return !!a.isRunning }).length
    property real now: Date.now()

    readonly property string headerDetail: {
        if (root.loading)
            return qsTr("Reading harness usage…")
        if (root.agents.length === 0)
            return qsTr("No active harnesses")
        const parts = [root.fmt(root.todayTokens) + " tokens today"]
        if (root.activeCount > 0)
            parts.push(root.activeCount + " active")
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
            return "% quota"
        if ((Number(agent.today) || 0) > 0)
            return "tokens today"
        if ((Number(agent.totalPrompts) || 0) > 0)
            return "prompts"
        return "tokens"
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
            const lbl = String(lim.label || qsTr("Quota"))
            const st = String(agent.status || "")
            return st !== "" ? (lbl + " · " + st) : lbl
        }
        const m = String(agent.topModel || "")
        if (m !== "")
            return m.replace(/^claude-/, "").replace(/^gpt-/, "GPT-").slice(0, 28)
        return agent.isDefault ? qsTr("Configured default harness") : qsTr("Local harness")
    }

    function barRightText(agent: var): string {
        if (hasQuota(agent)) {
            const lim = mainLimit(agent)
            const r = resets(String(lim.resetsAt || ""))
            return r !== "" ? r : qsTr("Active window")
        }
        const inT = Number(agent.inT) || 0
        const outT = Number(agent.outT) || 0
        if (inT + outT > 0)
            return fmt(outT) + " out · " + fmt(inT) + " in"
        if ((Number(agent.sessions) || 0) > 0)
            return agent.sessions + " sessions"
        return ""
    }

    function cardSubtext(agent: var): string {
        const parts = []
        if ((Number(agent.today) || 0) > 0 && hasQuota(agent))
            parts.push(fmt(agent.today) + " tokens today")
        if ((Number(agent.week) || 0) > 0)
            parts.push(agent.week + " msgs / 7d")
        if ((Number(agent.cacheT) || 0) > 0)
            parts.push(fmt(agent.cacheT) + " cached")
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
            title: qsTr("AI Usage")
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

    EmptyState {
        visible: !root.loading && root.agents.length === 0
        width: parent.width
        icon: "sparkles"
        title: qsTr("No AI usage yet")
        description: qsTr("Usage and quota metrics appear once an AI coding harness is active.")
    }

    ListView {
        id: agentList

        visible: root.agents.length > 0
        width: parent.width
        height: Math.min(Tokens.px(390), Math.max(Tokens.px(120), contentHeight))
        clip: true
        spacing: Tokens.space.sm
        boundsBehavior: Flickable.StopAtBounds
        model: root.agents

        delegate: MetricCard {
            id: agentCard

            required property var modelData

            width: agentList.width
            icon: root.glyph(String(agentCard.modelData.id ?? ""))
            label: String(agentCard.modelData.name ?? "")
                + (String(agentCard.modelData.tier ?? "") !== "" ? (" · " + agentCard.modelData.tier) : "")
            value: root.cardValue(agentCard.modelData)
            unit: root.cardUnit(agentCard.modelData)
            delta: agentCard.modelData.isRunning ? qsTr("Running") : (agentCard.modelData.isDefault ? qsTr("Default") : "")
            deltaTone: agentCard.modelData.isRunning ? "success" : "accent"
            subtext: root.cardSubtext(agentCard.modelData)

            ColumnLayout {
                width: parent.width
                spacing: Tokens.space.xs

                UsageBar {
                    Layout.fillWidth: true
                    segmented: true
                    segments: 16
                    autoThreshold: true
                    progress: root.barProgress(agentCard.modelData)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.sm

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        text: root.barLeftText(agentCard.modelData)
                    }

                    TextLabel {
                        role: "caption"
                        tone: "secondary"
                        tabular: true
                        text: root.barRightText(agentCard.modelData)
                    }
                }
            }
        }
    }
}
