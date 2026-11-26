pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AgentUsage: per-agent usage + active harness detection from Omarchy's collectors
// (~/.local/state/omarchy/agents/usage/*.json), the user's configured default agent
// (~/.config/omarchy/defaults/agent), and live running harness processes (e.g. opencode,
// agy, claude, codex, cursor, pi, copilot).
Singleton {
  id: root
  property var agents: []
  property string defaultAgent: ""
  property var runningIds: []
  property bool loaded: false
  property real refreshedAt: 0
  readonly property real age: refreshedAt > 0 ? Date.now() - refreshedAt : Infinity

  property real fetchedAt: 0
  property int watchers: 0
  function watch(on) { watchers = Math.max(0, watchers + (on ? 1 : -1)) }
  function refresh() { if (!proc.running) proc.running = true }

  // Run Omarchy's collectors:
  // - On explicit force refresh (or when local-stats harnesses like opencode are open),
  //   run a full update for active/default/running harnesses so local transcripts refresh too.
  // - Background refreshes remain rate-limited to avoid hammering remote quota APIs.
  function collect(force) {
    if (collector.running) return
    if (!force && Date.now() - fetchedAt < 180000) return
    var seen = ({}), ids = []
    function pushId(id) {
      var s = String(id || "").trim()
      if (/^[a-z0-9_-]+$/.test(s) && !seen[s]) { seen[s] = true; ids.push(s) }
    }
    agents.forEach(function (a) { pushId(a.id) })
    pushId(defaultAgent)
    runningIds.forEach(pushId)
    if (force) {
      collector.command = ids.length > 0 ? ["omarchy-agent-usage-update"].concat(ids) : ["omarchy-agent-usage-update"]
    } else {
      collector.command = ["omarchy-agent-usage-update", "--limits-only"].concat(ids)
    }
    collector.running = true
  }

  Process { id: collector; onExited: { root.refresh() } }
  Timer { interval: 5000; repeat: true; running: root.watchers > 0; onTriggered: root.refresh() }
  Timer { interval: 30000; repeat: true; running: root.watchers > 0; onTriggered: root.collect(false) }
  Timer { interval: 15 * 60 * 1000; repeat: true; running: true; onTriggered: root.collect(false) }
  function refreshIfOlder(ms) { if (age > ms) refresh() }

  Component.onCompleted: {
    var c = Cache.get("agents")
    if (Array.isArray(c)) { agents = c; loaded = true }
  }

  // Probe default agent, running harness processes, and all usage JSON records in one shell call.
  Process {
    id: proc
    command: ["bash", "-c",
      'def=""; [ -f "$HOME/.config/omarchy/defaults/agent" ] && read -r def < "$HOME/.config/omarchy/defaults/agent"; '
      + 'echo "DEFAULT\t${def}"; '
      + 'run=""; for bin in opencode claude codex agy antigravity cursor cursor-agent pi omp copilot gemini kimi qwen hermes crush devin amp; do '
      + '  if pgrep -x "$bin" >/dev/null 2>&1 || pgrep -f "/bin/$bin(\\s|$)" >/dev/null 2>&1; then '
      + '    id="$bin"; [ "$id" = "antigravity" ] && id="agy"; [ "$id" = "cursor-agent" ] && id="cursor"; '
      + '    run="$run $id"; '
      + '  fi; '
      + 'done; echo "RUNNING\t${run# }"; '
      + 'jq -c \'{id, name, ready, hasLocalStats, tier: .tierLabel, status: .usageStatusText, limits, limitsStale, limitsFetchedAt, todayTotalTokens, todayPrompts, todaySessions, recentDays, totalPrompts, totalSessions, activeDays, modelUsage}\' "$HOME"/.local/state/omarchy/agents/usage/*.json 2>/dev/null']
    stdout: StdioCollector { onStreamFinished: {
      var defId = "", runMap = ({}), runList = [], all = [], fetched = 0
      String(text || "").split("\n").forEach(function (l) {
        if (!l.trim()) return
        if (l.indexOf("DEFAULT\t") === 0) {
          defId = l.slice(8).trim()
          if (defId === "cursor-agent") defId = "cursor"
          return
        }
        if (l.indexOf("RUNNING\t") === 0) {
          l.slice(8).trim().split(/\s+/).forEach(function (id) {
            if (id && !runMap[id]) { runMap[id] = true; runList.push(id) }
          })
          return
        }
        try {
          var a = JSON.parse(l)
          var id = String(a.id || "")
          if (!id) return
          var isDefault = id === defId
          var isRunning = !!runMap[id]
          var today = +a.todayTotalTokens || 0
          var totalPrompts = +a.totalPrompts || 0
          var hasActivity = a.ready === true || today > 0 || totalPrompts > 0 || isDefault || isRunning
          if (!hasActivity) return

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
          fetched = Math.max(fetched, +a.limitsFetchedAt || 0)
          all.push({
            id: id,
            name: String(a.name || id).slice(0, 30),
            tier: String(a.tier || "").slice(0, 20),
            status: String(a.status || "").slice(0, 36),
            ready: a.ready === true,
            isDefault: isDefault,
            isRunning: isRunning,
            limits: lim,
            limitsStale: a.limitsStale === true,
            top: known.length ? Math.max.apply(null, known.map(function (x) { return x.percent })) : -1,
            today: today,
            prompts: +a.todayPrompts || 0,
            todaySessions: +a.todaySessions || 0,
            days: days,
            week: days.reduce(function (s, v) { return s + v }, 0),
            dayMax: Math.max.apply(null, days.concat([1])),
            inT: inT, outT: outT, cacheT: cacheT, topModel: top,
            totalPrompts: totalPrompts,
            sessions: +a.totalSessions || 0,
            activeDays: +a.activeDays || 0
          })
        } catch (e) {}
      })

      // Sort: running first, then today's tokens, then default harness, then total prompts.
      all.sort(function (a, b) {
        return ((b.isRunning ? 1 : 0) - (a.isRunning ? 1 : 0))
            || (b.today - a.today)
            || ((b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0))
            || (b.top - a.top)
            || (b.totalPrompts - a.totalPrompts)
      })
      all = all.slice(0, 8)
      root.defaultAgent = defId
      root.runningIds = runList
      if (JSON.stringify(all) !== JSON.stringify(root.agents)) root.agents = all
      root.fetchedAt = fetched
      root.loaded = true
      root.refreshedAt = Date.now()
      Cache.put("agents", all)
    } }
    onExited: root.loaded = true
  }
}
