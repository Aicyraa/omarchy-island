import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."
import "../services"

// The idle form of the CENTRE pill: just the clock. (Workspaces and the battery live in their own capsules beside
// the pill, see Island.qml; the hover form is HoverPreview.)
//
// AUDIO VISUALIZER (ported from the old jee.clock widget): while any MPRIS player is playing, five thin bars,
// driven by cava (assets/viz-bar.conf), slide in on the left of the time (edge -5 -> 3, scale 0.65 -> 1, opacity
// fade) and the pill makes room for them. widthFor() is read by Island to size the idle pill.
Item {
  id: form
  property var win: null                  // the PanelWindow (for screen name + widget toggling)

  readonly property int pad: 22
  TextMetrics { id: timeM; font.pixelSize: 12; font.weight: Theme.weightLabel; text: "00:00" }
  readonly property real timeW: timeM.advanceWidth

  readonly property bool playing: Quickshell.env("ISLAND_FORCE_VIZ") === "1" || Mpris.players.values.some(function (p) { return p.isPlaying })
  readonly property real vizRoom: 29      // along-bar room the bars need: 3 px edge + 18 px of bars + an 8 px gap to the time
  property real vizWidth: playing ? vizRoom : 0
  property real vizEdge: playing ? 3 : -5
  Behavior on vizWidth { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
  Behavior on vizEdge { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

  function widthFor() { return Math.ceil(timeW + 2 * pad + (playing ? vizRoom : 0)) }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  // ---- spectrum: 5 bands, only while playing and this form is showing ----
  property var spectrum: [0, 0, 0, 0, 0]
  Process {
    running: form.playing && form.visible
    command: ["cava", "-p", Qt.resolvedUrl("../assets/viz-bar.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function (line) { form.spectrum = line.split(";").slice(0, 5).map(function (v) { return Math.max(0, Math.min(1000, Number(v) || 0)) }) }
    }
    onRunningChanged: if (!running) form.spectrum = [0, 0, 0, 0, 0]
  }

  // The time; the pair [bars | time] stays centred in the pill.
  Text {
    id: timeText
    objectName: "clockText"
    x: Math.round((form.width - width) / 2 + form.vizWidth / 2)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text; font.pixelSize: 12; font.weight: Theme.weightLabel
    TapHandler { onTapped: IslandState.toggleWidget("calendar", form.win ? form.win.screenName : "") }
  }

  Grid {
    id: bars
    visible: opacity > 0.001
    opacity: form.playing ? 1 : 0
    scale: form.playing ? 1 : 0.65
    transformOrigin: Item.Center
    x: timeText.x - form.vizWidth + form.vizEdge
    anchors.verticalCenter: parent.verticalCenter
    columns: 5; spacing: 2
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Repeater {
      model: 5
      Item {
        required property int index
        readonly property real level: Math.max(2, 12 * Math.sqrt((form.spectrum[index] || 0) / 1000))
        width: 2; height: 12
        Rectangle {
          anchors.centerIn: parent; width: 2; height: parent.level; radius: 1; color: Theme.text
          Behavior on height { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
        }
      }
    }
  }
}
