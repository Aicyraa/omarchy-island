import QtQuick
import Quickshell.Io
import ".."
import "../services"

// System: CPU, memory and CPU temperature as equal cards with real line charts, then detail tiles (load, uptime,
// disk, swap, network, clock speed) and the three busiest processes.
// History comes from Stats, a shared 2 s ring buffer (the one documented exception to
// "nothing polls while hidden"), so the charts are already full when this opens.
WidgetPanel {
  id: root
  preferredWidth: 620
  hint: "Esc close"
  // Fallback mode only: when Stats.alwaysOn is false it samples while this is open.
  Component.onCompleted: Stats.sampling = true
  Component.onDestruction: Stats.sampling = false

  readonly property real tempWarn: Stats.temp > 80 ? 2 : (Stats.temp > 70 ? 1 : 0)

  // ---- details: read by assets/sysinfo.sh every 3 s, only while this widget is open ----
  property real load1: 0; property real load5: 0; property real load15: 0
  property real uptimeSec: 0
  property real diskUsed: 0; property real diskSize: 1
  property real swapTotal: 0; property real swapUsed: 0
  property real freqMHz: 0; property int cores: 0
  property real rxRate: 0; property real txRate: 0
  property var prevNet: null
  property var procs: []
  function bytes(n) { n = Number(n) || 0; var u = ["B", "KB", "MB", "GB", "TB"], i = 0; while (n >= 1000 && i < 4) { n /= 1000; i++ } return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + " " + u[i] }
  function dur(sec) { var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
    return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m") }
  Process {
    id: info
    command: ["bash", Qt.resolvedUrl("../assets/sysinfo.sh").toString().replace("file://", "")]
    stdout: StdioCollector { onStreamFinished: {
      var procs = [], now = Date.now()
      text.split("\n").forEach(function (l) {
        var p = l.split(" ")
        if (p[0] === "load") { root.load1 = +p[1]; root.load5 = +p[2]; root.load15 = +p[3] }
        else if (p[0] === "up") root.uptimeSec = +p[1]
        else if (p[0] === "disk") { root.diskUsed = +p[1]; root.diskSize = Math.max(1, +p[2]) }
        else if (p[0] === "swap") { root.swapTotal = (+p[1]) * 1024; root.swapUsed = (+p[1] - +p[2]) * 1024 }
        else if (p[0] === "freq") { root.freqMHz = +p[1] }
        else if (p[0] === "cores") root.cores = +p[1]
        else if (p[0] === "net") {
          var rx = +p[1], tx = +p[2], pv = root.prevNet
          if (pv && now > pv.t) { root.rxRate = Math.max(0, (rx - pv.rx) / ((now - pv.t) / 1000)); root.txRate = Math.max(0, (tx - pv.tx) / ((now - pv.t) / 1000)) }
          root.prevNet = { rx: rx, tx: tx, t: now }
        }
        else if (p[0] === "proc") procs.push({ name: String(p[1]).slice(0, 24), cpu: (+p[2]) / Math.max(1, root.cores), mem: +p[3] })
      })
      root.procs = procs
    } }
  }
  Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!info.running) info.running = true }

  // A small stat tile: muted label over a value.
  component Tile2: Rectangle {
    id: t
    property string label; property string value; property real fraction: -1
    width: (parent.width - 2 * Theme.s12) / 3; height: 50; radius: Theme.tileRadius - 4; color: Theme.surface
    Text { x: Theme.s12; y: 8; textFormat: Text.PlainText; text: t.label; color: Theme.textMuted; font.pixelSize: 11 }
    Text { x: Theme.s12; y: 25; width: parent.width - 2 * Theme.s12; elide: Text.ElideRight; textFormat: Text.PlainText
      text: t.value; color: Theme.text; font.pixelSize: 13; font.weight: Theme.weightLabel }
    Rectangle { visible: t.fraction >= 0; x: Theme.s12; width: parent.width - 2 * Theme.s12; y: parent.height - 6; height: 3; radius: 1.5; color: Theme.mix(Theme.surface, Theme.text, 0.16)
      Rectangle { height: parent.height; radius: 1.5; width: parent.width * Math.min(1, t.fraction)
        color: t.fraction >= 0.9 ? Theme.dangerInk : (t.fraction >= 0.75 ? Theme.warningInk : Theme.accentInk) } }
  }

  component Card: Rectangle {
    id: card
    property string icon; property string label; property string value; property string unit
    property var hist: []; property color tint: Theme.accentInk
    width: (parent.width - 2 * Theme.s12) / 3; height: 128; radius: Theme.tileRadius + 4; color: Theme.surface
    Icon { x: Theme.s16; y: Theme.s16; name: card.icon; size: Theme.iconMd; color: card.tint }
    Text { x: Theme.s16 + Theme.iconMd + Theme.s8; y: Theme.s16; height: Theme.iconMd; verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText; text: card.label; color: Theme.textMuted; font.pixelSize: 12 }
    // value and unit share a baseline
    Item { x: Theme.s16; y: 42; width: parent.width - 2 * Theme.s16; height: 34
      Text { id: val; textFormat: Text.PlainText; text: card.value; color: Theme.text; font.pixelSize: 26; font.weight: Theme.weightStrong }
      Text { anchors.left: val.right; anchors.leftMargin: 4; anchors.baseline: val.baseline; textFormat: Text.PlainText
        text: card.unit; color: Theme.textMuted; font.pixelSize: 12 } }
    Sparkline { x: Theme.s16; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s16
      width: parent.width - 2 * Theme.s16; height: 36; samples: card.hist; color: card.tint }
  }

  Row {
    width: parent.width; spacing: Theme.s12
    Card { icon: "cpu"; label: "CPU"; value: Math.round(Stats.cpu * 100); unit: "%"; hist: Stats.cpuHist }
    Card { icon: "ram"; label: "Memory"; value: Stats.memUsedGb.toFixed(1); unit: "/ " + Stats.memTotalGb.toFixed(0) + " GB"; hist: Stats.memHist }
    Card { icon: "thermo"; label: "CPU temperature"; value: Stats.temp > 0 ? Math.round(Stats.temp) : "—"; unit: Stats.temp > 0 ? "°C" : ""; hist: Stats.tempHist
      tint: root.tempWarn === 2 ? Theme.dangerInk : (root.tempWarn === 1 ? Theme.warningInk : Theme.accentInk) }
  }

  // ---- detail tiles ----
  Flow {
    width: parent.width; spacing: Theme.s12
    Tile2 { label: "Load average"; value: root.load1.toFixed(2) + " · " + root.load5.toFixed(2) + " · " + root.load15.toFixed(2); fraction: root.cores > 0 ? root.load1 / root.cores : -1 }
    Tile2 { label: "Uptime"; value: root.dur(root.uptimeSec) }
    Tile2 { label: "CPU clock"; value: root.freqMHz > 0 ? (root.freqMHz / 1000).toFixed(2) + " GHz · " + root.cores + " cores" : "—" }
    Tile2 { label: "Disk /"; value: root.bytes(root.diskUsed) + " / " + root.bytes(root.diskSize); fraction: root.diskUsed / root.diskSize }
    Tile2 { label: "Swap"; value: root.swapTotal > 0 ? root.bytes(root.swapUsed) + " / " + root.bytes(root.swapTotal) : "None"; fraction: root.swapTotal > 0 ? root.swapUsed / root.swapTotal : -1 }
    Tile2 { label: "Network"; value: "↓ " + root.bytes(root.rxRate) + "/s  ↑ " + root.bytes(root.txRate) + "/s" }
  }

  // ---- busiest processes (share of the whole CPU) ----
  Column {
    width: parent.width; spacing: 2; visible: root.procs.length > 0
    Text { textFormat: Text.PlainText; text: "Busiest processes"; color: Theme.textMuted; font.pixelSize: 11; bottomPadding: 4 }
    Repeater { model: root.procs
      delegate: Item { required property var modelData; width: parent.width; height: 20
        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 200; elide: Text.ElideRight; textFormat: Text.PlainText
          text: modelData.name; color: Theme.text; font.pixelSize: 12 }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: 128; anchors.verticalCenter: parent.verticalCenter; width: 48; height: 4; radius: 2
          color: Theme.mix(Theme.pill, Theme.text, 0.14)
          Rectangle { height: parent.height; radius: 2; width: parent.width * Math.min(1, modelData.cpu / 100); color: Theme.accentInk } }
        Text { anchors.right: parent.right; anchors.rightMargin: 72; anchors.verticalCenter: parent.verticalCenter; width: 44; horizontalAlignment: Text.AlignRight
          textFormat: Text.PlainText; text: modelData.cpu.toFixed(modelData.cpu < 10 ? 1 : 0) + "%"; color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel }
        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 64; horizontalAlignment: Text.AlignRight
          textFormat: Text.PlainText; text: modelData.mem.toFixed(1) + "% mem"; color: Theme.textMuted; font.pixelSize: 11 } }
    }
  }
}
