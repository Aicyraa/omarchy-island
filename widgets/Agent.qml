import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Agents: the important part of Omarchy's AI-agent usage tracking, which agents are
// near a limit and when it resets. Reads the files Omarchy's agents plugin already
// maintains; this widget fetches nothing itself.
// Fixed columns (label | bar | percent | reset) so values align across every row.
// "0% used" and "no data" look different: no data shows a dash and a dimmed track.
WidgetPanel {
  id: root
  preferredWidth: 560
  hint: "R refresh · Esc close"
  property var agents: []
  property bool loading: true

  function load() { loading = true; proc.running = true }
  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { load(); e.accepted = true } }
  Component.onCompleted: load()

  // Original per-provider glyphs (not brand logos).
  function glyph(id) {
    return { claude: "spark", codex: "brackets", copilot: "plane", cursor: "pointer" }[String(id)] || "bot"
  }
  function resets(iso) {
    var t = Date.parse(iso); if (isNaN(t)) return ""
    var m = Math.max(0, Math.round((t - Date.now()) / 60000))
    return m < 60 ? "resets in " + m + "m" : m < 1440 ? "resets in " + Math.round(m / 60) + "h" : "resets in " + Math.round(m / 1440) + "d"
  }

  Process {
    id: proc
    command: ["bash", "-c", "jq -c 'select(.ready==true and (.limits|length)>0) | {id, name, tier: .tierLabel, limits}' \"$HOME\"/.local/state/omarchy/agents/usage/*.json 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: {
      var out = []
      text.split("\n").forEach(function (l) {
        if (!l.trim()) return
        try {
          var a = JSON.parse(l)
          var lim = (a.limits || []).filter(function (x) { return x && typeof x === "object" }).slice(0, 3)
          if (!lim.length) return
          var known = lim.filter(function (x) { return typeof x.percent === "number" })
          out.push({ id: String(a.id || ""), name: String(a.name).slice(0, 30), tier: String(a.tier || "").slice(0, 20), limits: lim,
                     top: known.length ? Math.max.apply(null, known.map(function (x) { return x.percent })) : -1 })
        } catch (e) {}
      })
      out.sort(function (a, b) { return b.top - a.top })
      root.agents = out.slice(0, 5); root.loading = false
    } }
    onExited: root.loading = false
  }

  compact: !loading && agents.length === 0
  Text { textFormat: Text.PlainText; text: "Agents"; color: Theme.text; font.pixelSize: 15; font.weight: Theme.weightStrong; visible: root.agents.length > 0 }
  Text { visible: !root.loading && root.agents.length === 0; textFormat: Text.PlainText
    text: "No agents with usage limits"; color: Theme.textMuted; font.pixelSize: 13 }
  Text { visible: root.loading; textFormat: Text.PlainText; text: "Reading usage…"; color: Theme.textMuted; font.pixelSize: 13 }

  Repeater {
    model: root.agents
    delegate: Column {
      required property var modelData
      width: parent.width; spacing: Theme.s8
      Row { spacing: Theme.s8
        Icon { name: root.glyph(modelData.id); size: Theme.iconMd; color: modelData.top >= 0.9 ? Theme.dangerInk : Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
        Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter
          text: modelData.name + (modelData.tier !== "" ? "  ·  " + modelData.tier : ""); color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel } }
      Repeater {
        model: modelData.limits
        delegate: Item {
          required property var modelData
          readonly property bool known: typeof modelData.percent === "number"
          width: parent.width; height: 22
          Text { id: lbl; x: 0; width: 150; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; textFormat: Text.PlainText
            text: String(modelData.label || "").slice(0, 30); color: Theme.textMuted; font.pixelSize: 11 }
          Text { id: rst; anchors.right: parent.right; width: 92; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText; text: known ? root.resets(modelData.resetsAt) : ""; color: Theme.textMuted; font.pixelSize: 11 }
          Text { id: pct; anchors.right: rst.left; anchors.rightMargin: Theme.s8; width: 38; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText; text: known ? Math.round(modelData.percent * 100) + "%" : "—"; color: known ? Theme.text : Theme.textMuted; font.pixelSize: 11; font.weight: Theme.weightLabel }
          Rectangle { anchors.left: lbl.right; anchors.leftMargin: Theme.s8; anchors.right: pct.left; anchors.rightMargin: Theme.s8
            anchors.verticalCenter: parent.verticalCenter; height: 8; radius: 4; color: Theme.surface; opacity: known ? 1 : 0.5
            Rectangle { visible: known; height: parent.height; radius: 4; width: parent.width * Math.min(1, modelData.percent)
              color: modelData.percent >= 0.9 ? Theme.dangerInk : (modelData.percent >= 0.7 ? Theme.warningInk : Theme.accentInk) } }
        }
      }
    }
  }
}
