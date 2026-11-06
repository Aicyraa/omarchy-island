pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AgentUsage: per-agent usage read from the files Omarchy's agents plugin maintains (nothing is fetched).
// Restored from the cache at startup and refreshed in the background, so the Agent widget opens with data.
Singleton {
  id: root
  property var agents: []
  property bool loaded: false
  property real refreshedAt: 0
  readonly property real age: refreshedAt > 0 ? Date.now() - refreshedAt : Infinity

  function refresh() { if (!proc.running) proc.running = true }
  function refreshIfOlder(ms) { if (age > ms) refresh() }

  Component.onCompleted: { var c = Cache.get("agents"); if (Array.isArray(c)) { agents = c; loaded = true } }

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
      out = out.slice(0, 4)
      if (JSON.stringify(out) !== JSON.stringify(root.agents)) root.agents = out
      root.loaded = true; root.refreshedAt = Date.now()
      Cache.put("agents", out)
    } }
    onExited: root.loaded = true
  }
}
