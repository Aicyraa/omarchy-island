import QtQuick
import Quickshell.Io
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
  property var agents: []
  property bool loading: true
  readonly property real todayTokens: agents.reduce(function (s, a) { return s + a.today }, 0)
  readonly property real weekTokens: agents.reduce(function (s, a) { return s + a.week }, 0)
  readonly property int todayPrompts: agents.reduce(function (s, a) { return s + a.prompts }, 0)

  function load() { loading = true; proc.running = true }
  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { load(); e.accepted = true } }
  Component.onCompleted: load()

  // Original per-provider glyphs (not brand logos).
  function glyph(id) { return { claude: "spark", codex: "brackets", copilot: "plane", cursor: "pointer" }[String(id)] || "bot" }
  function resets(iso) {
    var t = Date.parse(iso); if (isNaN(t)) return ""
    var m = Math.max(0, Math.round((t - Date.now()) / 60000))
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

  Process {
    id: proc
    command: ["bash", "-c", "jq -c 'select(.ready==true or (.totalPrompts // 0) > 0) | {id, name, tier: .tierLabel, limits, todayTotalTokens, todayPrompts, todaySessions, recentDays, totalPrompts, totalSessions, activeDays, modelUsage}' \"$HOME\"/.local/state/omarchy/agents/usage/*.json 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: {
      var out = []
      text.split("\n").forEach(function (l) {
        if (!l.trim()) return
        try {
          var a = JSON.parse(l)
          var lim = (a.limits || []).filter(function (x) { return x && typeof x === "object" }).slice(0, 3)
          var known = lim.filter(function (x) { return typeof x.percent === "number" })
          var inT = 0, outT = 0, cacheT = 0, top = "", topV = -1
          var mu = a.modelUsage || {}
          Object.keys(mu).forEach(function (k) {
            var m = mu[k] || {}, i = +m.inputTokens || 0, o = +m.outputTokens || 0
            inT += i; outT += o; cacheT += (+m.cacheReadInputTokens || 0) + (+m.cacheCreationInputTokens || 0)
            if (i + o > topV) { topV = i + o; top = k }
          })
          var days = (a.recentDays || []).slice(-7).map(function (d) { return +d.messageCount || 0 })
          out.push({ id: String(a.id || ""), name: String(a.name || "").slice(0, 30), tier: String(a.tier || "").slice(0, 20), limits: lim,
                     top: known.length ? Math.max.apply(null, known.map(function (x) { return x.percent })) : -1,
                     today: +a.todayTotalTokens || 0, prompts: +a.todayPrompts || 0, days: days,
                     week: days.reduce(function (s, v) { return s + v }, 0), dayMax: Math.max.apply(null, days.concat([1])),
                     inT: inT, outT: outT, cacheT: cacheT, topModel: top,
                     totalPrompts: +a.totalPrompts || 0, sessions: +a.totalSessions || 0, activeDays: +a.activeDays || 0 })
        } catch (e) {}
      })
      out.sort(function (a, b) { return (b.today - a.today) || (b.top - a.top) || (b.totalPrompts - a.totalPrompts) })
      root.agents = out.slice(0, 4); root.loading = false
    } }
    onExited: root.loading = false
  }

  compact: !loading && agents.length === 0
  // ---- summary ----
  Item {
    visible: root.agents.length > 0; width: parent.width; height: 24
    Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Agents"
      color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong }
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
                  Rectangle { anchors.bottom: parent.bottom; width: 5; radius: 2
                    height: Math.max(2, 18 * parent.modelData / card.modelData.dayMax)
                    color: parent.index === card.modelData.days.length - 1 ? Theme.accentInk : card.track } } } }
            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 0
              Text { anchors.right: parent.right; textFormat: Text.PlainText; text: root.fmt(card.modelData.today)
                color: card.modelData.today > 0 ? Theme.text : Theme.textMuted; font.pixelSize: 14; font.weight: Theme.weightStrong }
              Text { anchors.right: parent.right; textFormat: Text.PlainText; text: "tokens today"; color: Theme.textMuted; font.pixelSize: 9 } }
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
              Rectangle { visible: known; height: parent.height; radius: 4; width: parent.width * Math.min(1, modelData.percent)
                color: modelData.percent >= 0.9 ? Theme.dangerInk : (modelData.percent >= 0.7 ? Theme.warningInk : Theme.accentInk) } }
          }
        }

        // analytics line
        Text {
          width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 10
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
