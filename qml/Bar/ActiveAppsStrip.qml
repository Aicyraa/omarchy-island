pragma ComponentBehavior: Bound

import QtQuick
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"

// ActiveAppsStrip: sits beside WorkspaceStrip; collapses cleanly to 0 width when no apps are open.
Item {
  id: root

  readonly property var apps: ActiveApps.apps
  readonly property bool hasApps: apps.length > 0

  implicitWidth: hasApps ? appsRow.implicitWidth : 0
  implicitHeight: 28
  visible: implicitWidth > 0.5
  clip: true

  Behavior on implicitWidth {
    enabled: !Tokens.reducedMotion && !Tokens.gameMode
    NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
  }

  Row {
    id: appsRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Repeater {
      model: root.apps

      delegate: Item {
        id: appBtn
        required property var modelData

        width: 24
        height: 24

        property real revealOpacity: (Tokens.reducedMotion || Tokens.gameMode) ? 1.0 : 0.0
        property real revealScale: (Tokens.reducedMotion || Tokens.gameMode) ? 1.0 : 0.78

        opacity: revealOpacity
        scale: revealScale

        Behavior on revealOpacity {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
        }
        Behavior on revealScale {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
        }

        Component.onCompleted: {
          revealOpacity = 1.0
          revealScale = 1.0
        }

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: modelData.title || modelData.className || qsTr("Application")

        Keys.onSpacePressed: function(e) {
          ActiveApps.focusApp(appBtn.modelData.address)
          e.accepted = true
        }
        Keys.onReturnPressed: function(e) {
          ActiveApps.focusApp(appBtn.modelData.address)
          e.accepted = true
        }

        Rectangle {
          anchors.fill: parent
          radius: Tokens.radius.sm
          color: appMouse.containsMouse ? Tokens.veilHoverOf(Tokens.surfaceStyle) : "transparent"

          Behavior on color {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            ColorAnimation { duration: Tokens.motion.fast }
          }
        }

        FocusRing {
          active: appBtn.activeFocus
          ringRadius: Tokens.radius.sm
        }

        Image {
          id: appImg
          anchors.centerIn: parent
          width: 16
          height: 16
          source: appBtn.modelData.iconSource || ""
          sourceSize: Qt.size(Math.max(1, Math.ceil(16 * Tokens.dpr)), Math.max(1, Math.ceil(16 * Tokens.dpr)))
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
          asynchronous: true
          visible: appBtn.modelData.iconSource !== "" && status === Image.Ready
        }

        Icon {
          anchors.centerIn: parent
          name: "app-window"
          size: 16
          tone: appBtn.modelData.focused ? "primary" : "secondary"
          visible: appBtn.modelData.iconSource === "" || appImg.status !== Image.Ready
        }

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 1
          anchors.horizontalCenter: parent.horizontalCenter
          width: 4
          height: 2
          radius: 1
          color: Tokens.color.accent
          visible: !!appBtn.modelData.focused
        }

        MouseArea {
          id: appMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: ActiveApps.focusApp(appBtn.modelData.address)
        }
      }
    }
  }
}
