import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../../QuickshellDS/Theme"

// Audio visualizer: `bars` columns driven by REAL spectrum data from cava (PipeWire monitor).
// cava only runs while `active` (visible AND playing), so nothing runs otherwise. If cava is missing or
// fails, the bars simply stay at their resting height rather than faking motion.
Item {
  id: root
  property bool active: false
  property int bars: 24
  property bool mirror: false                   // bars grow up and down from the centre line
  property real progress: -1                    // 0..1 playback position; bars past it are dimmed. -1: off
  property color color: Tokens.color.accent
  property var levels: []                       // 0..1 per bar (cava sends 0..~1000 whatever ascii_max_value says)

  implicitHeight: 28
  readonly property real gap: 3
  readonly property real barW: Math.max(2, (width - (bars - 1) * gap) / bars)

  Process {
    id: cava
    running: root.active
    command: ["cava", "-p", Qt.resolvedUrl("../../../assets/cava.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function (line) {
        var p = line.split(";"), out = []
        for (var i = 0; i < root.bars; i++) out.push(Math.min(1, (parseInt(p[i]) || 0) / 700))
        root.levels = out
      }
    }
  }
  onActiveChanged: if (!active) levels = []

  Repeater {
    model: root.bars
    delegate: Rectangle {
      required property int index
      readonly property real v: root.levels.length > index ? root.levels[index] : 0
      // Bars past the playhead are dimmed when the visualizer doubles as a progress bar.
      readonly property bool ahead: root.progress >= 0 && (index + 0.5) / root.bars > root.progress
      x: index * (root.barW + root.gap); width: root.barW; radius: width / 2
      height: Math.max(3, v * root.height)
      // mirror: grows up and down from the centre line; otherwise it grows up from the base
      y: root.mirror ? (root.height - height) / 2 : root.height - height
      color: root.color; opacity: ahead ? 0.28 : 0.55 + 0.45 * v
      Behavior on height { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 70 } }
    }
  }
}
