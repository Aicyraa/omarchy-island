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

  component Card: Rectangle {
    id: card
    property string icon; property string label; property string value; property string unit
    property var hist: []; property color tint: Theme.accentInk
    width: (parent.width - 2 * Theme.s12) / 3; height: 104; radius: Theme.tileRadius; color: Theme.surface
    // An icon chip (the same as the list rows) and the label beside it.
    Rectangle { x: Theme.s16; y: Theme.s16; width: 30; height: 30; radius: Theme.radiusChip
      color: Qt.rgba(card.tint.r, card.tint.g, card.tint.b, 0.16)
      Icon { anchors.centerIn: parent; name: card.icon; size: Theme.iconSm + 2; color: card.tint } }
    Text { x: Theme.s16 + 30 + Theme.s8; y: Theme.s16; height: 30; verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText; text: card.label; color: Theme.textMuted; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
    // value and unit share a baseline
    Item { x: Theme.s16; y: 54; width: parent.width - 2 * Theme.s16; height: 34
      Text { id: val; textFormat: Text.PlainText; text: card.value; color: Theme.text; font.pixelSize: Theme.typeValue; font.weight: Theme.weightStrong }
      Text { anchors.left: val.right; anchors.leftMargin: 4; anchors.baseline: val.baseline; textFormat: Text.PlainText
        text: card.unit; color: Theme.textMuted; font.pixelSize: Theme.typeBody } }
    Sparkline { x: Theme.s16; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s12
      width: parent.width - 2 * Theme.s16; height: 22; samples: card.hist; color: card.tint }
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
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Load average"; value: root.load1.toFixed(2) + " · " + root.load5.toFixed(2) + " · " + root.load15.toFixed(2); fraction: root.cores > 0 ? root.load1 / root.cores : -1 }
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "CPU clock"; value: root.freqMHz > 0 ? (root.freqMHz / 1000).toFixed(2) + " GHz · " + root.cores + " cores" : "—" }
    StatTile { width: (parent.width - 2 * Theme.s12) / 3; label: "Disk /"; value: root.bytes(root.diskUsed) + " / " + root.bytes(root.diskSize); fraction: root.diskUsed / root.diskSize }
    StatTile { width: (parent.width - Theme.s12) / 2; label: "Swap"; value: root.swapTotal > 0 ? root.bytes(root.swapUsed) + " / " + root.bytes(root.swapTotal) : "None"; fraction: root.swapTotal > 0 ? root.swapUsed / root.swapTotal : -1 }
    StatTile { width: (parent.width - Theme.s12) / 2; label: "Network"; value: root.rxRate >= 0 ? "↓ " + root.bytes(root.rxRate) + "/s  ↑ " + root.bytes(root.txRate) + "/s" : "measuring…" }
  }

  // ---- busiest processes (share of the whole CPU): a letter badge, the name, a bar and the numbers ----
  Column {
    width: parent.width; spacing: Theme.s8; visible: root.procs.length > 0
    Text { textFormat: Text.PlainText; text: "Busiest processes"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
    Repeater { model: root.procs
      delegate: Rectangle { required property var modelData; required property int index
        width: parent.width; height: 40; radius: Theme.radiusChip; color: Theme.surface; antialiasing: true
        readonly property color tint: modelData.cpu >= 50 ? Theme.dangerInk : (modelData.cpu >= 25 ? Theme.warningInk : Theme.accentInk)
        Rectangle { id: badge; x: Theme.s8; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 13; antialiasing: true
          color: Theme.mix(Theme.surface, parent.tint, 0.22)
          Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: String(modelData.name).charAt(0).toUpperCase(); color: parent.parent.tint
            font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel } }
        Text { id: pname; anchors.left: badge.right; anchors.leftMargin: Theme.s8; anchors.right: nums.left; anchors.rightMargin: Theme.s8; y: 6
          elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.name; color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
        Rectangle { anchors.left: badge.right; anchors.leftMargin: Theme.s8; anchors.right: parent.right; anchors.rightMargin: Theme.s12
          y: parent.height - 11; height: 4; radius: 2; antialiasing: true; color: Theme.mix(Theme.surface, Theme.text, 0.14)
          Rectangle { height: parent.height; radius: 2; antialiasing: true; color: parent.parent.tint
            width: Math.max(4, parent.width * Math.min(1, modelData.cpu / 100))
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } } }
        Row { id: nums; anchors.right: parent.right; anchors.rightMargin: Theme.s12; y: 6; spacing: Theme.s8
          Text { textFormat: Text.PlainText; text: modelData.cpu.toFixed(modelData.cpu < 10 ? 1 : 0) + "%"; color: Theme.text; font.pixelSize: Theme.typeBody; font.weight: Theme.weightLabel }
          Text { textFormat: Text.PlainText; text: modelData.mem.toFixed(1) + "% mem"; color: Theme.textMuted; font.pixelSize: Theme.typeLabel; anchors.baseline: parent.children[0].baseline } }
      }
    }
  }
}
