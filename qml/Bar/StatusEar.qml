pragma ComponentBehavior: Bound

import QtQuick
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"

// StatusEar: subtle 10x16 micro accent indicator dot on the far right edge.
Item {
  id: root

  property string screenName: ""

  readonly property bool hasActiveIndicator:
    Indicators.dnd || Indicators.nightLight || Indicators.stayAwake || Indicators.updateAvailable

  readonly property bool shown: ConfigStore.barItemVisible("statusEar") && hasActiveIndicator

  implicitWidth: shown ? 10 : 0
  implicitHeight: 16
  visible: shown

  activeFocusOnTab: shown
  Accessible.role: Accessible.Button
  Accessible.name: qsTr("Active status indicators")

  Keys.onSpacePressed: function(e) {
    IslandState.toggleWidget("settings", root.screenName)
    e.accepted = true
  }
  Keys.onReturnPressed: function(e) {
    IslandState.toggleWidget("settings", root.screenName)
    e.accepted = true
  }

  FocusRing {
    active: root.activeFocus
    ringRadius: Tokens.radius.pill
  }

  Rectangle {
    anchors.centerIn: parent
    width: mouse.containsMouse ? 7 : 5
    height: mouse.containsMouse ? 7 : 5
    radius: width / 2
    color: Tokens.color.accent

    Behavior on width {
      enabled: !Tokens.reducedMotion && !Tokens.gameMode
      NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
    }
    Behavior on height {
      enabled: !Tokens.reducedMotion && !Tokens.gameMode
      NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: IslandState.toggleWidget("settings", root.screenName)
  }
}
