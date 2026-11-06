import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Audio visualizer: `bars` columns driven by REAL spectrum data from cava (PipeWire monitor).
// cava only runs while `active` (visible AND playing), so nothing runs otherwise. If cava is missing or
// fails, the bars simply stay at their resting height rather than faking motion.
Item {
  id: root
  property bool active: false
  property int bars: 24
  property color color: Theme.accent
  property var levels: []                       // 0..1 per bar
  visible: active                               // nothing to draw (no resting dotted line) unless playing

  implicitHeight: 28
  readonly property real gap: 3
  readonly property real barW: Math.max(2, (width - (bars - 1) * gap) / bars)

  Process {
    id: cava
    running: root.active
    command: ["cava", "-p", Qt.resolvedUrl("../assets/cava.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function (line) {
        var p = line.split(";"), out = []
        for (var i = 0; i < root.bars; i++) out.push(Math.min(1, (parseInt(p[i]) || 0) / 100))
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
      x: index * (root.barW + root.gap); width: root.barW; radius: width / 2
      height: Math.max(3, v * root.height); anchors.bottom: parent.bottom
      color: root.color; opacity: 0.55 + 0.45 * v
      Behavior on height { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 70 } }
    }
  }
}
