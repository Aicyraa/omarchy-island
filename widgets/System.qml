import QtQuick
import Quickshell.Io
import ".."
import "../services"

// System: CPU, memory and CPU temperature with short history graphs.
// Samples every 1.5 s, and ONLY while this widget is open (it is destroyed on close).
// The CPU temperature is read from the x86_pkg_temp thermal zone; the discrete GPU is
// never touched (reading it would keep it awake).
Item {
  id: root
  focus: true
  property string hint: "Esc close"
  property var cpuHist: []
  property var memHist: []
  property real cpu: 0
  property real mem: 0
  property real temp: 0
  property real memUsedGb: 0
  property real memTotalGb: 0
  property var prev: null

  function push(arr, v) { var a = arr.concat([v]); return a.length > 40 ? a.slice(a.length - 40) : a }

  Process { id: sampler; running: true
    command: ["bash", "-c",
      "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; " +
      "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && echo TEMP $(cat $z/temp); done"]
    stdout: StdioCollector { onStreamFinished: {
      var lines = text.trim().split("\n"), total = 0, avail = 0
      lines.forEach(function (l) {
        if (l.indexOf("cpu ") === 0) {
          var f = l.trim().split(/\s+/).slice(1).map(Number)
          var idle = f[3] + (f[4] || 0), all = f.reduce(function (a, b) { return a + b }, 0)
          if (root.prev) { var dt = all - root.prev.all; if (dt > 0) root.cpu = 1 - (idle - root.prev.idle) / dt }
          root.prev = { idle: idle, all: all }
        } else if (l.indexOf("MemTotal") === 0) total = parseInt(l.split(/\s+/)[1])
        else if (l.indexOf("MemAvailable") === 0) avail = parseInt(l.split(/\s+/)[1])
        else if (l.indexOf("TEMP") === 0) root.temp = parseInt(l.split(" ")[1]) / 1000
      })
      if (total > 0) { root.mem = 1 - avail / total; root.memTotalGb = total / 1048576; root.memUsedGb = (total - avail) / 1048576 }
      root.cpuHist = root.push(root.cpuHist, root.cpu); root.memHist = root.push(root.memHist, root.mem)
    } } }
  Timer { interval: 1500; running: true; repeat: true; onTriggered: if (!sampler.running) sampler.running = true }

  component Graph: Item {
    id: g
    property string icon; property string title; property string value; property var hist: []; property color tint: Theme.accent
    width: (root.width - 36 - 20) / 3; height: root.height - 36
    Rectangle { anchors.fill: parent; radius: 22; color: Theme.surface }
    Icon { x: 16; y: 16; name: g.icon; size: 18; color: g.tint }
    Text { x: 42; y: 16; textFormat: Text.PlainText; text: g.title; color: Theme.textMuted; font.pixelSize: 12 }
    Text { x: 16; y: 42; textFormat: Text.PlainText; text: g.value; color: Theme.text; font.pixelSize: 26; font.bold: true }
    Row { x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 16; spacing: 2; height: 54
      Repeater { model: 40
        delegate: Item { required property int index
          width: (g.width - 32 - 78) / 40; height: 54
          readonly property real v: index < 40 - g.hist.length ? 0 : g.hist[index - (40 - g.hist.length)]
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 1
            height: Math.max(2, parent.v * parent.height); color: g.tint; opacity: parent.v > 0 ? 0.9 : 0.2 } } } }
  }

  Row { x: 18; y: 18; spacing: 10
    Graph { icon: "cpu"; title: "CPU"; value: Math.round(root.cpu * 100) + "%"; hist: root.cpuHist }
    Graph { icon: "ram"; title: "Memory"; value: root.memUsedGb.toFixed(1) + " / " + root.memTotalGb.toFixed(0) + " GB"; hist: root.memHist; tint: Theme.success }
    Graph { icon: "thermo"; title: "CPU temperature"; value: root.temp > 0 ? Math.round(root.temp) + "°C" : "n/a"
      hist: root.temp > 0 ? [root.temp / 100] : []; tint: root.temp > 85 ? Theme.danger : (root.temp > 70 ? Theme.warning : Theme.accent) }
  }
}
