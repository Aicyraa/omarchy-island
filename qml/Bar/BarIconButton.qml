pragma ComponentBehavior: Bound

import QtQuick
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"

// BarIconButton: uniform 28x28 hit target with 15px icon, optional badge dot, hover veil & focus ring.
Item {
  id: root

  property string name: ""
  property string tone: "primary"
  property string accessibleName: ""
  property bool badgeDot: false
  property string badgeTone: "accent" // "accent" | "success" | "warning" | "danger" | "info"
  property string badgePosition: "topRight" // "topRight" | "bottom"

  signal clicked()
  signal rightClicked()

  readonly property color badgeColor: {
    switch (root.badgeTone) {
    case "success": return Tokens.color.success
    case "warning": return Tokens.color.warning
    case "danger":  return Tokens.color.danger
    case "info":    return Tokens.color.info
    default:        return Tokens.color.accent
    }
  }

  implicitWidth: Tokens.size.hitMin
  implicitHeight: Tokens.size.hitMin

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.name

  Keys.onSpacePressed: function(e) {
    root.clicked()
    e.accepted = true
  }
  Keys.onReturnPressed: function(e) {
    root.clicked()
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

  Icon {
    anchors.centerIn: parent
    name: root.name
    size: 15
    tone: root.tone
  }

  Rectangle {
    visible: root.badgeDot
    width: 4
    height: 4
    radius: 2
    color: root.badgeColor
    anchors.horizontalCenter: root.badgePosition === "bottom" ? parent.horizontalCenter : undefined
    anchors.bottom: root.badgePosition === "bottom" ? parent.bottom : undefined
    anchors.bottomMargin: root.badgePosition === "bottom" ? 2 : 0
    anchors.right: root.badgePosition === "topRight" ? parent.right : undefined
    anchors.top: root.badgePosition === "topRight" ? parent.top : undefined
    anchors.rightMargin: root.badgePosition === "topRight" ? 4 : 0
    anchors.topMargin: root.badgePosition === "topRight" ? 4 : 0
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(ev) {
      if (ev.button === Qt.RightButton)
        root.rightClicked()
      else
        root.clicked()
    }
  }
}
