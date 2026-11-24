pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../Core"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"

// ClockCluster: stacked centered tabular monospace HH mm over compact uppercase ddd d MMM.
Item {
  id: root

  property string screenName: ""

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  implicitWidth: Math.max(timeLabel.implicitWidth, dateLabel.implicitWidth) + Tokens.space.sm * 2
  implicitHeight: 28

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: qsTr("Clock: %1, %2").arg(timeLabel.text).arg(dateLabel.text)

  Keys.onSpacePressed: function(e) {
    IslandState.toggleWidget("calendar", root.screenName)
    e.accepted = true
  }
  Keys.onReturnPressed: function(e) {
    IslandState.toggleWidget("calendar", root.screenName)
    e.accepted = true
  }

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

  Column {
    anchors.centerIn: parent
    spacing: -1

    TextLabel {
      id: timeLabel
      objectName: "clockText"
      anchors.horizontalCenter: parent.horizontalCenter
      role: "body"
      font.family: Tokens.type.monoFamily
      font.weight: Font.Medium
      tabular: true
      text: Qt.formatDateTime(clock.date, "HH mm")
    }

    TextLabel {
      id: dateLabel
      anchors.horizontalCenter: parent.horizontalCenter
      role: "caption"
      tone: "muted"
      font.pixelSize: 9
      font.letterSpacing: 0.8
      text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(ev) {
      if (ev.button === Qt.RightButton)
        IslandState.toggleWidget("worldclock", root.screenName)
      else
        IslandState.toggleWidget("calendar", root.screenName)
    }
  }
}
