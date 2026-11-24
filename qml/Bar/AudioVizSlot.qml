pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Core"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"

// AudioVizSlot: 5-bar cava visualizer visible only while MPRIS audio is playing
// (or ISLAND_FORCE_VIZ=1). Zero idle CPU when stopped.
Item {
  id: root

  property string screenName: ""

  readonly property bool playing: {
    if (Quickshell.env("ISLAND_FORCE_VIZ") === "1")
      return true
    var list = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying)
        return true
    }
    return false
  }

  property var levels: [0, 0, 0, 0, 0]

  implicitWidth: playing ? 28 : 0
  implicitHeight: 24
  visible: implicitWidth > 0.5
  clip: true

  Behavior on implicitWidth {
    enabled: !Tokens.reducedMotion && !Tokens.gameMode
    NumberAnimation { duration: Tokens.motion.normal; easing.type: Tokens.motion.easeOut }
  }

  activeFocusOnTab: playing
  Accessible.role: Accessible.Button
  Accessible.name: qsTr("Media visualizer")

  Keys.onSpacePressed: function(e) {
    IslandState.toggleWidget("media", root.screenName)
    e.accepted = true
  }
  Keys.onReturnPressed: function(e) {
    IslandState.toggleWidget("media", root.screenName)
    e.accepted = true
  }

  Process {
    id: cava
    running: root.playing && root.visible
    command: ["cava", "-p", Qt.resolvedUrl("../../assets/viz-bar.conf").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.split(";")
        var out = []
        for (var i = 0; i < 5; i++)
          out.push(Math.min(1, (parseInt(parts[i], 10) || 0) / 1000))
        root.levels = out
      }
    }
  }

  onPlayingChanged: if (!playing) levels = [0, 0, 0, 0, 0]

  // Hover-only background (no permanent highlight when active)
  Rectangle {
    anchors.fill: parent
    radius: Tokens.radius.sm
    color: mouse.containsMouse ? Tokens.veilHoverOf(Tokens.surfaceStyle) : "transparent"

    Behavior on color {
      enabled: !Tokens.reducedMotion && !Tokens.gameMode
      ColorAnimation { duration: Tokens.motion.fast }
    }
  }

  FocusRing {
    active: root.activeFocus
    ringRadius: Tokens.radius.sm
  }

  Row {
    anchors.centerIn: parent
    spacing: 2
    height: 14

    Repeater {
      model: 5

      delegate: Rectangle {
        required property int index
        readonly property real val: root.levels.length > index ? root.levels[index] : 0

        width: 3
        height: Math.max(3, Math.round(val * 14))
        anchors.verticalCenter: parent.verticalCenter
        radius: 1.5
        color: Tokens.color.accent

        Behavior on height {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: IslandState.toggleWidget("media", root.screenName)
  }
}
