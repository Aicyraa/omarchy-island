import QtQuick
import ".."
import "../services"

// System: CPU, memory and CPU temperature as equal cards with real line charts.
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

  component Card: Rectangle {
    id: card
    property string icon; property string label; property string value; property string unit
    property var hist: []; property color tint: Theme.accentInk
    width: (parent.width - 2 * Theme.s12) / 3; height: 150; radius: Theme.tileRadius + 4; color: Theme.surface
    Icon { x: Theme.s16; y: Theme.s16; name: card.icon; size: Theme.iconMd; color: card.tint }
    Text { x: Theme.s16 + Theme.iconMd + Theme.s8; y: Theme.s16; height: Theme.iconMd; verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText; text: card.label; color: Theme.textMuted; font.pixelSize: 12 }
    // value and unit share a baseline
    Item { x: Theme.s16; y: 46; width: parent.width - 2 * Theme.s16; height: 34
      Text { id: val; textFormat: Text.PlainText; text: card.value; color: Theme.text; font.pixelSize: 26; font.bold: true }
      Text { anchors.left: val.right; anchors.leftMargin: 4; anchors.baseline: val.baseline; textFormat: Text.PlainText
        text: card.unit; color: Theme.textMuted; font.pixelSize: 12 } }
    Sparkline { x: Theme.s16; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.s16
      width: parent.width - 2 * Theme.s16; height: 44; samples: card.hist; color: card.tint }
  }

  Row {
    width: parent.width; spacing: Theme.s12
    Card { icon: "cpu"; label: "CPU"; value: Math.round(Stats.cpu * 100); unit: "%"; hist: Stats.cpuHist }
    Card { icon: "ram"; label: "Memory"; value: Stats.memUsedGb.toFixed(1); unit: "/ " + Stats.memTotalGb.toFixed(0) + " GB"; hist: Stats.memHist }
    Card { icon: "thermo"; label: "CPU temperature"; value: Stats.temp > 0 ? Math.round(Stats.temp) : "—"; unit: Stats.temp > 0 ? "°C" : ""; hist: Stats.tempHist
      tint: root.tempWarn === 2 ? Theme.dangerInk : (root.tempWarn === 1 ? Theme.warningInk : Theme.accentInk) }
  }
}
