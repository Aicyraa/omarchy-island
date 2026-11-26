pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Services"
import "../../QuickshellDS/Theme"
import "../../QuickshellDS/Primitives"

Item {
  id: toast
  property string screenName: ""
  readonly property var n: IslandState.notifItem || ({})
  readonly property string preview: n.key !== undefined ? Notifs.previewOf(n) : ""
  readonly property string iconName: n.key !== undefined ? Notifs.iconNameOf(n) : ""
  readonly property real inset: Tokens.space.lg
  readonly property int motion: (IslandState.reducedMotion || Tokens.gameMode) ? 0 : 1
  readonly property int barSpace: 12

  Component.onCompleted: enter.restart()
  Connections {
    target: IslandState
    function onNotifSerialChanged() { enter.restart() }
  }

  NumberAnimation {
    id: enter
    target: thumb; property: "scale"; from: 0.78; to: 1
    duration: (Tokens.reducedMotion || Tokens.gameMode) ? 0 : Math.round(220 * Tokens.motionScale)
    easing.type: Easing.OutCubic
  }

  Item {
    id: body
    width: parent.width; height: parent.height; transformOrigin: Item.Top
    NotifThumb {
      id: thumb
      x: toast.inset; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -toast.barSpace / 2
      size: 40; badge: true; preview: toast.preview; iconName: toast.iconName
      transformOrigin: Item.Center
    }
    Column {
      anchors.left: thumb.right; anchors.leftMargin: Tokens.space.md
      anchors.right: parent.right; anchors.rightMargin: toast.inset
      anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -toast.barSpace / 2; spacing: 2
      TextLabel {
        width: parent.width; role: "subtitle"; tone: "primary"
        font.weight: Font.Medium
        text: toast.n.summary || toast.n.app || ""
      }
      TextLabel {
        width: parent.width; role: "body"; tone: "muted"
        visible: text !== ""
        text: toast.n.body || toast.n.app || ""
      }
    }
    SmoothRect {
      x: toast.inset; anchors.bottom: parent.bottom; anchors.bottomMargin: 9
      width: parent.width - 2 * toast.inset; height: 3; radius: 1.5
      color: Qt.rgba(Tokens.color.text.r, Tokens.color.text.g, Tokens.color.text.b, 0.10)
      SmoothRect {
        height: parent.height; radius: parent.radius
        width: parent.width * IslandState.notifLeft
        color: Tokens.color.accent
      }
    }
  }

  MouseArea {
    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onClicked: { IslandState.clearNotifs(); IslandState.openWidget("notifications", toast.screenName) }
  }
}
