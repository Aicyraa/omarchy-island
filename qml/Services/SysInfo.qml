pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// SysInfo: the System widget's detail data (load, uptime, disk, swap, clock, network rate, busiest processes),
// read by assets/sysinfo.sh. Kept here (not in the widget) so the last values are there the instant the widget
// opens; Prefetch refreshes it on startup and when the pointer nears the island, the widget refreshes it every 3 s
// while open. The network rate needs two samples, so it is only shown while the last two are close together.
Singleton {
  id: root
  property real load1: 0; property real load5: 0; property real load15: 0
  property real uptimeSec: 0
  property real diskUsed: 0; property real diskSize: 1
  property real swapTotal: 0; property real swapUsed: 0
  property real freqMHz: 0; property int cores: 0
  property real rxRate: -1; property real txRate: -1
  property var procs: []
  property real sampledAt: 0
  property var prevNet: null
  readonly property bool loaded: sampledAt > 0
  readonly property real age: sampledAt > 0 ? Date.now() - sampledAt : Infinity

  function refresh() { if (!proc.running) proc.running = true }
  function refreshIfOlder(ms) { if (age > ms) refresh() }

  Component.onCompleted: {
    var c = Cache.get("sysinfo")           // last values from the previous session: better than empty tiles
    if (c) { load1 = c.load1; load5 = c.load5; load15 = c.load15; uptimeSec = c.uptimeSec; diskUsed = c.diskUsed; diskSize = c.diskSize
      swapTotal = c.swapTotal; swapUsed = c.swapUsed; freqMHz = c.freqMHz; cores = c.cores; procs = c.procs || [] }
  }

  Process {
    id: proc
    command: ["bash", Qt.resolvedUrl("../assets/sysinfo.sh").toString().replace("file://", "")]
    stdout: StdioCollector { onStreamFinished: {
      var procs = [], now = Date.now()
      text.split("\n").forEach(function (l) {
        var p = l.split(" ")
        if (p[0] === "load") { root.load1 = +p[1]; root.load5 = +p[2]; root.load15 = +p[3] }
        else if (p[0] === "up") root.uptimeSec = +p[1]
        else if (p[0] === "disk") { root.diskUsed = +p[1]; root.diskSize = Math.max(1, +p[2]) }
        else if (p[0] === "swap") { root.swapTotal = (+p[1]) * 1024; root.swapUsed = (+p[1] - +p[2]) * 1024 }
        else if (p[0] === "freq") root.freqMHz = +p[1]
        else if (p[0] === "cores") root.cores = +p[1]
        else if (p[0] === "net") {
          var rx = +p[1], tx = +p[2], pv = root.prevNet
          if (pv && now - pv.t < 15000 && now > pv.t) {
            root.rxRate = Math.max(0, (rx - pv.rx) / ((now - pv.t) / 1000)); root.txRate = Math.max(0, (tx - pv.tx) / ((now - pv.t) / 1000)) }
          else { root.rxRate = -1; root.txRate = -1 }
          root.prevNet = { rx: rx, tx: tx, t: now }
        }
        else if (p[0] === "proc") procs.push({ pid: parseInt(p[1], 10) || 0, name: String(p[2] || "").slice(0, 24), cpu: (+p[3]) / Math.max(1, root.cores), mem: +p[4] })
      })
      root.procs = procs; root.sampledAt = now
      Cache.put("sysinfo", { load1: root.load1, load5: root.load5, load15: root.load15, uptimeSec: root.uptimeSec, diskUsed: root.diskUsed,
        diskSize: root.diskSize, swapTotal: root.swapTotal, swapUsed: root.swapUsed, freqMHz: root.freqMHz, cores: root.cores, procs: procs })
    } }
  }
}
