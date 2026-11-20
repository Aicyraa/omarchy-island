import QtQuick
import ".."
import "../services"

// NotifToast: the island's notification mode. The notification on screen: its picture (with the app's chip), its
// summary and body, and a thin track that drains over its life (paused while the pointer is on the pill, see
// State.notifAnim). Each new one that takes the pill settles in: the card drops and grows in, the picture pops.
// Click opens the Notifications widget and clears the toasts.
Item {
  id: toast
  property string screenName: ""
  readonly property var n: IslandState.notifItem || ({})
  readonly property string preview: n.key !== undefined ? Notifs.previewOf(n) : ""
  readonly property string iconName: n.key !== undefined ? Notifs.iconNameOf(n) : ""
  readonly property real inset: Theme.s16
  readonly property int motion: IslandState.reducedMotion ? 0 : 1
  // Room the drain bar takes at the bottom (its bottom margin + its height). The content is centred in what is left
  // above it, so the text keeps an even gap from the bar and from the top.
  readonly property int barSpace: 9 + 3

  // Settles in. Replays whenever a new notification takes the pill (notifSerial) and on first show.
  Component.onCompleted: enter.restart()
  Connections {
    target: IslandState
    function onNotifSerialChanged() { enter.restart() }
  }
  ParallelAnimation { id: enter
    NumberAnimation { target: body; property: "y"; from: -Theme.s8; to: 0
      duration: 300 * toast.motion; easing.type: Easing.OutCubic }
    NumberAnimation { target: body; property: "scale"; from: 0.96; to: 1
      duration: 320 * toast.motion; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
    NumberAnimation { target: body; property: "opacity"; from: 0; to: 1
      duration: 200 * toast.motion; easing.type: Easing.OutCubic }
    // The picture pops in a beat after the card lands.
    SequentialAnimation {
      PauseAnimation { duration: 70 * toast.motion }
      NumberAnimation { target: thumb; property: "scale"; from: 0.6; to: 1
        duration: 360 * toast.motion; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
  }

  Item { id: body; width: parent.width; height: parent.height; transformOrigin: Item.Top
    NotifThumb {
      id: thumb
      x: Theme.s12; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -toast.barSpace / 2
      size: 40; badge: true; preview: toast.preview; iconName: toast.iconName
      transformOrigin: Item.Center
    }
    Column {
      anchors.left: thumb.right; anchors.leftMargin: Theme.s12
      anchors.right: parent.right; anchors.rightMargin: toast.inset
      anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -toast.barSpace / 2; spacing: 2
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
        text: toast.n.summary || toast.n.app || ""
        color: Theme.text; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong; font.letterSpacing: 0.1 }
      Text { width: parent.width; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
        visible: text !== ""; text: toast.n.body || toast.n.app || ""
        color: Theme.textMuted; font.pixelSize: Theme.typeBody }
    }
    // The track and the drain. A soft track under the fill; both ends rounded.
    Rectangle {
      x: toast.inset; anchors.bottom: parent.bottom; anchors.bottomMargin: 9
      width: parent.width - 2 * toast.inset; height: 3; radius: 1.5
      color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
      Rectangle {
        height: parent.height; radius: parent.radius
        width: parent.width * IslandState.notifLeft
        color: Theme.accentFill
      }
    }
  }

  MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onClicked: { IslandState.clearNotifs(); IslandState.openWidget("notifications", toast.screenName) } }
}
