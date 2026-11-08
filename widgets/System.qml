import QtQuick
import ".."
import "../services"

// System: CPU, memory and CPU temperature as equal cards with real line charts, then detail tiles (load,
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

  dataLoading: !SysInfo.loaded
  readonly property real tempWarn: Stats.temp > 80 ? 2 : (Stats.temp > 70 ? 1 : 0)

  // ---- details: from the SysInfo service (kept warm by Prefetch); refreshed every 2.5 s while this is open ----
  readonly property real load1: SysInfo.load1; readonly property real load5: SysInfo.load5; readonly property real load15: SysInfo.load15
  readonly property real diskUsed: SysInfo.diskUsed; readonly property real diskSize: SysInfo.diskSize
  readonly property real swapTotal: SysInfo.swapTotal; readonly property real swapUsed: SysInfo.swapUsed
  readonly property real freqMHz: SysInfo.freqMHz; readonly property int cores: SysInfo.cores
  readonly property real rxRate: SysInfo.rxRate; readonly property real txRate: SysInfo.txRate
  readonly property var procs: SysInfo.procs
  function bytes(n) { n = Number(n) || 0; var u = ["B", "KB", "MB", "GB", "TB"], i = 0; while (n >= 1000 && i < 4) { n /= 1000; i++ } return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + " " + u[i] }
  function dur(sec) { var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
    return d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m") }
  Timer { interval: 2500; repeat: true; running: true; triggeredOnStart: true; onTriggered: SysInfo.refresh() }

  // A card: the hero (large, full-height chart) or a compact one with a small chart beside the value.
  component Card: Rectangle {
    id: card
    property bool hero: false
    property string icon; property string label; property string value; property string unit
    property var hist: []; property color tint: Theme.accentInk
    radius: Theme.tileRadius; color: Theme.surface
    // icon chip and label, the same as the list rows
    Rectangle { x: Theme.s12; y: Theme.s12; width: 28; height: 28; radius: Theme.radiusChip
      color: Qt.rgba(card.tint.r, card.tint.g, card.tint.b, 0.16)
      Icon { anchors.centerIn: parent; name: card.icon; size: Theme.iconSm; color: card.tint } }
    Text { x: Theme.s12 + 28 + Theme.s8; y: Theme.s12; height: 28; verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText; text: card.label; color: Theme.textMuted; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
    // value and unit share a baseline
    Item { x: Theme.s12; y: card.hero ? 52 : 46; width: card.hero ? parent.width - 2 * Theme.s12 : parent.width * 0.5; height: 36
      Text { id: val; textFormat: Text.PlainText; text: card.value; color: Theme.text
        font.pixelSize: card.hero ? 34 : Theme.typeTitle + 8; font.weight: Theme.weightStrong }
      Text { anchors.left: val.right; anchors.leftMargin: 4; anchors.baseline: val.baseline; textFormat: Text.PlainText
        text: card.unit; color: Theme.textMuted; font.pixelSize: Theme.typeBody } }
    // hero: a tall chart across the bottom; compact: a small chart on the right
    Sparkline { visible: card.hero
      x: Theme.s12; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s12
      width: parent.width - 2 * Theme.s12; height: 52
      samples: card.hist; color: card.tint; lineWidth: 2.5; fillAlpha: 0.28 }
    Sparkline { visible: !card.hero
      anchors.right: parent.right; anchors.rightMargin: Theme.s12; y: 50
      width: parent.width * 0.36; height: 22
      samples: card.hist; color: card.tint; lineWidth: 2; fillAlpha: 0.26 }
  }

  // Asymmetric: a large CPU card on the left; memory and temperature stacked on the right.
  readonly property real colL: (width - Theme.s12) * 0.58
  readonly property real colR: width - Theme.s12 - colL
  Row {
    width: parent.width; spacing: Theme.s12
    Card { hero: true; width: root.colL; height: 152; icon: "cpu"; label: "CPU"; value: Math.round(Stats.cpu * 100); unit: "%"; hist: Stats.cpuHist }
    Column {
      width: root.colR; spacing: Theme.s12
      Card { width: parent.width; height: 70; icon: "ram"; label: "Memory"; value: Stats.memUsedGb.toFixed(1); unit: "/ " + Stats.memTotalGb.toFixed(0) + " GB"; hist: Stats.memHist }
      Card { width: parent.width; height: 70; icon: "thermo"; label: "Temperature"; value: Stats.temp > 0 ? Math.round(Stats.temp) : "—"; unit: Stats.temp > 0 ? "°C" : ""; hist: Stats.tempHist
        tint: root.tempWarn === 2 ? Theme.dangerInk : (root.tempWarn === 1 ? Theme.warningInk : Theme.accentInk) }
    }
  }

  // ---- details, split unevenly too: three on the left, two on the right ----
  Row {
    width: parent.width; spacing: Theme.s12
    Column {
      width: root.colL; spacing: Theme.s8
      StatTile { width: parent.width; label: "Load average"; value: root.load1.toFixed(2) + " · " + root.load5.toFixed(2) + " · " + root.load15.toFixed(2); fraction: root.cores > 0 ? root.load1 / root.cores : -1 }
      StatTile { width: parent.width; label: "Disk /"; value: root.bytes(root.diskUsed) + " / " + root.bytes(root.diskSize); fraction: root.diskUsed / root.diskSize }
    }
    Column {
      width: root.colR; spacing: Theme.s8
      StatTile { width: parent.width; label: "CPU clock"; value: root.freqMHz > 0 ? (root.freqMHz / 1000).toFixed(2) + " GHz · " + root.cores + " cores" : "—" }
      StatTile { width: parent.width; label: "Swap"; value: root.swapTotal > 0 ? root.bytes(root.swapUsed) + " / " + root.bytes(root.swapTotal) : "None"; fraction: root.swapTotal > 0 ? root.swapUsed / root.swapTotal : -1 }
    }
  }

  // ---- busiest processes: three slim rows (a badge, the name, the share, a hairline bar under it) ----
  Column {
    width: parent.width; spacing: Theme.s4; visible: root.procs.length > 0
    // The header line: the busiest processes, and the network rates on the right (kept off the details to save height)
    Item { width: parent.width; height: 16
      Text { anchors.left: parent.left; textFormat: Text.PlainText; text: "Busiest now"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
      Text { anchors.right: parent.right; textFormat: Text.PlainText; color: Theme.textMuted; font.pixelSize: Theme.typeCaption
        text: root.rxRate >= 0 ? "Network  ↓ " + root.bytes(root.rxRate) + "/s  ↑ " + root.bytes(root.txRate) + "/s" : "Network  measuring…" } }
    Repeater { model: root.procs.slice(0, 3)
      delegate: Rectangle { required property var modelData; required property int index
        width: parent.width; height: 28; radius: Theme.radiusChip; color: Theme.surface; antialiasing: true
        readonly property color tint: modelData.cpu >= 50 ? Theme.dangerInk : (modelData.cpu >= 25 ? Theme.warningInk : Theme.accentInk)
        Rectangle { id: badge; x: Theme.s8; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; radius: 9; antialiasing: true
          color: Theme.mix(Theme.surface, parent.tint, 0.22)
          Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: String(modelData.name).charAt(0).toUpperCase(); color: parent.parent.tint
            font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel } }
        Text { anchors.left: badge.right; anchors.leftMargin: Theme.s8; anchors.right: nums.left; anchors.rightMargin: Theme.s8
          anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.name
          color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
        Row { id: nums; anchors.right: parent.right; anchors.rightMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.s8
          Text { textFormat: Text.PlainText; text: modelData.cpu.toFixed(modelData.cpu < 10 ? 1 : 0) + "%"; color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
          Text { textFormat: Text.PlainText; text: modelData.mem.toFixed(1) + "% mem"; color: Theme.textMuted; font.pixelSize: Theme.typeCaption; anchors.baseline: parent.children[0].baseline } }
        Rectangle { anchors.left: badge.right; anchors.leftMargin: Theme.s8; anchors.right: parent.right; anchors.rightMargin: Theme.s12
          y: parent.height - 5; height: 2; radius: 1; color: Theme.mix(Theme.surface, Theme.text, 0.12)
          Rectangle { height: parent.height; radius: 1; color: parent.parent.tint
            width: Math.max(2, parent.width * Math.min(1, modelData.cpu / 100))
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } } }
      }
    }
  }
}
