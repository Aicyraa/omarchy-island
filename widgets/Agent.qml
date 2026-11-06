import QtQuick
import Quickshell.Io
import ".."
import "../services"

// Agent: only the important part of Omarchy's AI-agent usage tracking, which
// agents are close to a limit and when it resets. Data is read from the files
// Omarchy's agents plugin already maintains; this widget fetches nothing itself.
Item {
  id: root
  focus: true
  property string hint: "R refresh · Esc close"
  property var agents: []
  property bool loading: true

  function load() { loading = true; proc.running = true }
  Keys.onPressed: function (e) { if (e.key === Qt.Key_R) { load(); e.accepted = true } }
  Component.onCompleted: load()

  function resets(iso) {
    var t = Date.parse(iso); if (isNaN(t)) return ""
    var m = Math.max(0, Math.round((t - Date.now()) / 60000))
    return m < 60 ? "resets in " + m + "m" : m < 1440 ? "resets in " + Math.round(m / 60) + "h" : "resets in " + Math.round(m / 1440) + "d"
  }

  Process {
    id: proc
    command: ["bash", "-c", "jq -c 'select(.ready==true and (.limits|length)>0) | {name, tier: .tierLabel, limits}' \"$HOME\"/.local/state/omarchy/agents/usage/*.json 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: {
      var out = []
      text.split("\n").forEach(function (l) {
        if (!l.trim()) return
        try {
          var a = JSON.parse(l)
          var lim = (a.limits || []).filter(function (x) { return x && typeof x.percent === "number" }).slice(0, 3)
          if (lim.length) out.push({ name: String(a.name).slice(0, 30), tier: String(a.tier || "").slice(0, 20), limits: lim,
                                     top: Math.max.apply(null, lim.map(function (x) { return x.percent })) })
        } catch (e) {}
      })
      out.sort(function (a, b) { return b.top - a.top })
      root.agents = out.slice(0, 5); root.loading = false
    } }
    onExited: root.loading = false
  }

  Text { x: 22; y: 14; textFormat: Text.PlainText; text: "Agents"; color: Theme.text; font.pixelSize: 15; font.bold: true }
  Text { visible: !root.loading && root.agents.length === 0; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "No agents with usage limits"; color: Theme.textMuted; font.pixelSize: 13 }
  Text { visible: root.loading; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "Reading usage…"; color: Theme.textMuted; font.pixelSize: 13 }

  Column {
    x: 18; y: 48; width: root.width - 36; spacing: 8
    Repeater {
      model: root.agents
      delegate: Item {
        required property var modelData
        width: parent.width; height: 20 + modelData.limits.length * 26
        Icon { x: 4; y: 0; name: "bot"; size: 16; color: modelData.top >= 0.9 ? Theme.danger : Theme.accent }
        Text { x: 28; y: 0; textFormat: Text.PlainText; text: modelData.name + (modelData.tier !== "" ? "  ·  " + modelData.tier : "")
          color: Theme.text; font.pixelSize: 13; font.bold: true }
        Repeater { model: modelData.limits
          delegate: Item { required property var modelData; required property int index
            y: 22 + index * 26; width: parent.width; height: 22
            Text { x: 28; width: 150; elide: Text.ElideRight; textFormat: Text.PlainText
              text: String(modelData.label).slice(0, 30); color: Theme.textMuted; font.pixelSize: 11 }
            Rectangle { x: 184; y: 6; width: parent.width - 184 - 150; height: 8; radius: 4; color: Theme.surface
              Rectangle { height: parent.height; radius: 4; width: parent.width * Math.min(1, modelData.percent)
                color: modelData.percent >= 0.9 ? Theme.danger : (modelData.percent >= 0.7 ? Theme.warning : Theme.accent) } }
            Text { anchors.right: parent.right; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: 11
              text: Math.round(modelData.percent * 100) + "%  " + root.resets(modelData.resetsAt) } } }
      }
    }
  }
}
