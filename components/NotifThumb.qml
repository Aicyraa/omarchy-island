import QtQuick
import Quickshell.Widgets
import ".."

// NotifThumb: a notification's picture, shared by the Notifications widget and the toast.
// The image it is about when there is one, else the app's icon, else a bell. Images are decoded small, in memory.
// `badge`: with a picture, a small app-icon chip sits on its corner, so the sender stays visible.
Item {
  id: thumb
  property string preview: ""       // absolute image path, "" if none
  property string iconName: ""      // icon theme name, "" if none
  property int size: 48
  property bool badge: false
  readonly property int radius: Math.round(size * 13 / 48)
  readonly property bool hasImage: previewImg.status === Image.Ready
  width: size; height: size

  ClippingRectangle {
    anchors.fill: parent; radius: thumb.radius; color: Theme.surface
    Image { id: previewImg; anchors.fill: parent; visible: status === Image.Ready
      source: thumb.preview !== "" ? "file://" + thumb.preview : ""
      fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true; mipmap: true
      sourceSize.width: 192; sourceSize.height: 192 }
    Image { anchors.centerIn: parent; width: Math.round(thumb.size * 0.62); height: width
      visible: !thumb.hasImage && thumb.iconName !== ""
      source: thumb.iconName !== "" ? "image://icon/" + thumb.iconName : ""
      fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; sourceSize.width: 96; sourceSize.height: 96 }
    Icon { anchors.centerIn: parent; name: "bell"; size: Math.round(thumb.size * 0.42); color: Theme.textMuted
      visible: !thumb.hasImage && thumb.iconName === "" }
  }
  // A hairline ring: the picture reads as a tile, not a hole in the pill.
  Rectangle { anchors.fill: parent; radius: thumb.radius; color: "transparent"
    border.width: 1; border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10) }

  // App chip on the corner of a picture thumbnail. It overhangs the corner a little on purpose.
  Rectangle {
    id: chip
    visible: thumb.badge && thumb.hasImage && thumb.iconName !== ""
    width: Math.round(thumb.size * 0.44); height: width; radius: width / 2
    anchors.right: parent.right; anchors.bottom: parent.bottom
    anchors.rightMargin: -Math.round(width * 0.25); anchors.bottomMargin: -Math.round(width * 0.25)
    color: Theme.pillBase
    border.width: 1; border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
    Image { anchors.centerIn: parent; width: Math.round(chip.width * 0.66); height: width
      source: chip.visible ? "image://icon/" + thumb.iconName : ""
      fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; sourceSize.width: 64; sourceSize.height: 64 }
  }
}
