import QtQuick
import ".."
import "../services"

// Agents: usage at a glance, from the files Omarchy's agents plugin already maintains (nothing is fetched here).
// A summary line (tokens today and over 7 days), then one compact card per agent:
//   [glyph name · tier]  ............  [7-day bars]  [today's tokens]
//   limit rows: label | bar | percent | reset          (aligned across every card)
//   one muted line: output / input / cached tokens, prompts, sessions, top model
// "0% used" and "no data" look different: no data shows a dash and a dimmed track.
WidgetPanel {
  id: root
  preferredWidth: 600
  hint: "R refresh · Esc close"
  // From the AgentUsage service: cached at startup and refreshed in the background, so this opens with data.
  readonly property var agents: AgentUsage.agents
  readonly property bool loading: !AgentUsage.loaded
  readonly property real todayTokens: agents.reduce(function (s, a) { return s + a.today }, 0)
  readonly property real weekTokens: agents.reduce(function (s, a) { return s + a.week }, 0)
  readonly property int todayPrompts: agents.reduce(function (s, a) { return s + a.prompts }, 0)

  // Live: while this is open the service re-reads the files every 5 s and runs the collectors every 3 min (R forces a run).
  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { AgentUsage.collect(true); e.accepted = true } }
  Component.onCompleted: { AgentUsage.watch(true); AgentUsage.refresh(); AgentUsage.collect(false) }
  Component.onDestruction: AgentUsage.watch(false)
  // The "resets in" countdowns and "updated" age tick on their own.
  property real now: Date.now()
  Timer { interval: 15000; repeat: true; running: true; onTriggered: root.now = Date.now() }
  function ago(ms) { var m = Math.round((root.now - ms) / 60000); return m < 1 ? "just now" : m < 60 ? m + " min ago" : Math.round(m / 60) + " h ago" }

  // Original per-provider glyphs (not brand logos).
  function glyph(id) { return { claude: "spark", codex: "brackets", copilot: "plane", cursor: "pointer" }[String(id)] || "bot" }
  function resets(iso) {
    var t = Date.parse(iso); if (isNaN(t)) return ""
    var m = Math.max(0, Math.round((t - root.now) / 60000))
    return m < 60 ? "resets in " + m + "m" : m < 1440 ? "resets in " + Math.round(m / 60) + "h" : "resets in " + Math.round(m / 1440) + "d"
  }
  function fmt(n) {
    n = Number(n) || 0
    if (n >= 1e9) return (n / 1e9).toFixed(n >= 1e10 ? 0 : 1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + "K"
    return String(Math.round(n))
  }
  function shortModel(m) { return String(m).replace(/^claude-/, "").replace(/^gpt-/, "GPT-").slice(0, 22) }

  dataLoading: !AgentUsage.loaded
  compact: !loading && agents.length === 0
  // ---- summary ----
  Item {
    visible: root.agents.length > 0; width: parent.width; height: 24
    Row { anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; visible: AgentUsage.fetchedAt > 0
        text: "Updated " + root.ago(AgentUsage.fetchedAt); color: Theme.textMuted; font.pixelSize: 11 } }
    Row { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s12
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Today"; color: Theme.textMuted; font.pixelSize: 11 }
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: root.fmt(root.todayTokens) + " tokens"
        color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel }
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "7 days"; color: Theme.textMuted; font.pixelSize: 11 }
      Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: root.fmt(root.weekTokens)
        color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel }
    }
  }
  Text { visible: !root.loading && root.agents.length === 0; textFormat: Text.PlainText
    text: "No agent usage yet"; color: Theme.textMuted; font.pixelSize: 13 }
  Text { visible: root.loading; textFormat: Text.PlainText; text: "Reading usage…"; color: Theme.textMuted; font.pixelSize: 13 }

  // ---- one card per agent ----
  Repeater {
    model: root.agents
    delegate: Rectangle {
      id: card
      required property var modelData
      readonly property color track: Theme.mix(Theme.surface, Theme.text, 0.16)     // visible on the card in every theme
      width: parent.width; radius: Theme.tileRadius - 4; color: Theme.surface
      height: body.implicitHeight + 2 * Theme.s12
      Column {
        id: body
        x: Theme.s12; y: Theme.s12; width: parent.width - 2 * Theme.s12; spacing: 6

        // header: identity, 7-day bars, today
        Item { width: parent.width; height: 22
          Row { spacing: Theme.s8; anchors.verticalCenter: parent.verticalCenter
            Icon { name: root.glyph(card.modelData.id); size: Theme.iconMd; anchors.verticalCenter: parent.verticalCenter
              color: card.modelData.top >= 0.9 ? Theme.dangerInk : Theme.accentInk }
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText
              text: card.modelData.name; color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
            Text { anchors.verticalCenter: parent.verticalCenter; visible: card.modelData.tier !== ""; textFormat: Text.PlainText
              text: card.modelData.tier; color: Theme.textMuted; font.pixelSize: 11 } }
          Row { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s12
            // last 7 days, today highlighted
            Row { spacing: 3; anchors.verticalCenter: parent.verticalCenter; visible: card.modelData.week > 0
              Repeater { model: card.modelData.days
                delegate: Item { required property int index; required property real modelData
                  width: 5; height: 18
                  Rectangle { antialiasing: true; anchors.bottom: parent.bottom; width: 5; radius: 2
                    height: Math.max(2, 18 * parent.modelData / card.modelData.dayMax)
                    color: parent.index === card.modelData.days.length - 1 ? Theme.accentInk : card.track } } } }
            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 0
              Text { anchors.right: parent.right; textFormat: Text.PlainText; text: root.fmt(card.modelData.today)
                color: card.modelData.today > 0 ? Theme.text : Theme.textMuted; font.pixelSize: 14; font.weight: Theme.weightStrong }
              Text { anchors.right: parent.right; textFormat: Text.PlainText; text: "tokens today"; color: Theme.textMuted; font.pixelSize: 11 } }
          } }

        // limits
        Repeater {
          model: card.modelData.limits
          delegate: Item {
            required property var modelData
            readonly property bool known: typeof modelData.percent === "number"
            width: body.width; height: 20
            Text { id: lbl; x: 0; width: 130; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; textFormat: Text.PlainText
              text: String(modelData.label || "").slice(0, 30); color: Theme.textMuted; font.pixelSize: 11 }
            Text { id: rst; anchors.right: parent.right; width: 86; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText; text: known ? root.resets(modelData.resetsAt) : ""; color: Theme.textMuted; font.pixelSize: 11 }
            Text { id: pct; anchors.right: rst.left; anchors.rightMargin: Theme.s8; width: 36; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText; text: known ? Math.round(modelData.percent * 100) + "%" : "—"; color: known ? Theme.text : Theme.textMuted
              font.pixelSize: 11; font.weight: Theme.weightLabel }
            Rectangle { anchors.left: lbl.right; anchors.leftMargin: Theme.s8; anchors.right: pct.left; anchors.rightMargin: Theme.s8
              anchors.verticalCenter: parent.verticalCenter; height: 8; radius: 4; color: card.track; opacity: known ? 1 : 0.5
              Rectangle { antialiasing: true; visible: known; height: parent.height; radius: 4; width: parent.width * Math.min(1, modelData.percent)
                color: modelData.percent >= 0.9 ? Theme.dangerInk : (modelData.percent >= 0.7 ? Theme.warningInk : Theme.accentInk) } }
          }
        }

        // analytics line
        Text {
          width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 11
          visible: text !== ""
          text: {
            var m = card.modelData, p = []
            if (m.outT + m.inT > 0) p.push(root.fmt(m.outT) + " out · " + root.fmt(m.inT) + " in" + (m.cacheT > 0 ? " · " + root.fmt(m.cacheT) + " cached" : ""))
            if (m.totalPrompts > 0) p.push(m.totalPrompts + " prompts · " + m.sessions + " sessions")
            if (m.topModel !== "") p.push(root.shortModel(m.topModel))
            return p.join("  |  ")
          }
        }
      }
    }
  }
}
