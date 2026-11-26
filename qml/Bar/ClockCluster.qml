pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../Core"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"

// ClockCluster: time-only tabular monospace clock (day/date lives in the right status cluster).
Item {
  id: root

  property string screenName: ""
  property bool vertical: false

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  implicitWidth: root.vertical ? 32 : (hTimeLabel.implicitWidth + Tokens.space.sm * 2)
  implicitHeight: root.vertical ? (vClockCol.implicitHeight + Tokens.space.xs * 2) : 28

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: qsTr("Clock: %1").arg(Qt.formatDateTime(clock.date, "HH:mm"))

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

  TextLabel {
    id: hTimeLabel
    visible: !root.vertical
    objectName: root.vertical ? "" : "clockText"
    anchors.centerIn: parent
    role: "body"
    font.family: Tokens.type.monoFamily
    font.weight: Font.Medium
    tabular: true
    text: Qt.formatDateTime(clock.date, "HH:mm")
  }

  Column {
    id: vClockCol
    visible: root.vertical
    anchors.centerIn: parent
    spacing: -2

    TextLabel {
      objectName: root.vertical ? "clockText" : ""
      anchors.horizontalCenter: parent.horizontalCenter
      role: "sm"
      font.family: Tokens.type.monoFamily
      font.weight: Font.Medium
      tabular: true
      text: Qt.formatDateTime(clock.date, "HH")
    }

    TextLabel {
      anchors.horizontalCenter: parent.horizontalCenter
      role: "sm"
      tone: "secondary"
      font.family: Tokens.type.monoFamily
      font.weight: Font.Medium
      tabular: true
      text: Qt.formatDateTime(clock.date, "mm")
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
