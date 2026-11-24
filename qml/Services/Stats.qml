pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Stats: CPU, memory and CPU-temperature history for the System widget.
//
// THE ONE DELIBERATE EXCEPTION to "nothing runs while hidden": a single 2-second
// timer samples /proc into a 60-sample ring buffer (2 minutes of history), so the
// graphs are already full when the widget opens. It reads three small files with
// FileView (no process is spawned per tick). The measured cost is in the README;
// set `alwaysOn: false` to fall back to sampling only while the System widget is
// open (`sampling: true` from the widget).
Singleton {
  id: root
  // Test aid: ISLAND_STATS_OFF=1 starts in the fallback mode (sample only while the System widget is open).
  property bool alwaysOn: Quickshell.env("ISLAND_STATS_OFF") !== "1"
  property bool sampling: false                 // set by the widget in the fallback mode
  readonly property bool active: alwaysOn || sampling
  readonly property int slots: 60

  property var cpuHist: []
  property var memHist: []
  property var tempHist: []
  property real cpu: 0
  property real mem: 0
  property real memUsedGb: 0
  property real memTotalGb: 0
  property real temp: 0
  property var prev: null

  function push(arr, v) { var a = arr.concat([v]); return a.length > slots ? a.slice(a.length - slots) : a }

  FileView { id: statFile; path: "/proc/stat"
    onLoaded: {
      var line = text().split("\n")[0]
      var f = line.trim().split(/\s+/).slice(1).map(Number)
      var idle = f[3] + (f[4] || 0), all = f.reduce(function (a, b) { return a + b }, 0)
      if (root.prev) { var dt = all - root.prev.all; if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.prev.idle) / dt)) }
      root.prev = { idle: idle, all: all }
      root.cpuHist = root.push(root.cpuHist, root.cpu)
    } }
  FileView { id: memFile; path: "/proc/meminfo"
    onLoaded: {
      var t = 0, a = 0
      text().split("\n").forEach(function (l) {
        if (l.indexOf("MemTotal") === 0) t = parseInt(l.split(/\s+/)[1])
        else if (l.indexOf("MemAvailable") === 0) a = parseInt(l.split(/\s+/)[1])
      })
      if (t > 0) { root.mem = 1 - a / t; root.memTotalGb = t / 1048576; root.memUsedGb = (t - a) / 1048576
        root.memHist = root.push(root.memHist, root.mem) }
    } }
  // The CPU package sensor is found once; the discrete GPU is never read (it would stay awake).
  Process { running: true
    command: ["bash", "-c", "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && echo $z/temp && break; done"]
    stdout: StdioCollector { onStreamFinished: { var p = text.trim(); if (p !== "") tempFile.path = p } } }
  FileView { id: tempFile
    onLoaded: { var v = parseInt(text()) / 1000; if (!isNaN(v)) { root.temp = v; root.tempHist = root.push(root.tempHist, Math.max(0, Math.min(1, (v - 30) / 70))) } } }

  function sample() { statFile.reload(); memFile.reload(); if (tempFile.path !== "") tempFile.reload() }
  Timer { interval: 2000; repeat: true; running: root.active; triggeredOnStart: true; onTriggered: root.sample() }
}
