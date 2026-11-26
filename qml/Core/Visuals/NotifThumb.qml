pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "../../QuickshellDS/Theme"
import "../../QuickshellDS/Primitives"

Item {
  id: thumb
  property string preview: ""
  property string iconName: ""
  property int size: 48
  property bool badge: false
  readonly property int radius: Math.round(size * 13 / 48)
  readonly property bool hasImage: previewImg.status === Image.Ready
  width: size; height: size

  ClippingRectangle {
    anchors.fill: parent; radius: thumb.radius; color: Tokens.color.surface
    Image {
      id: previewImg; anchors.fill: parent; visible: status === Image.Ready
      source: thumb.preview !== "" ? "file://" + thumb.preview : ""
      fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true; mipmap: true
      sourceSize.width: 192; sourceSize.height: 192
    }
    Image {
      anchors.centerIn: parent; width: Math.round(thumb.size * 0.62); height: width
      visible: !thumb.hasImage && thumb.iconName !== ""
      source: thumb.iconName !== "" ? "image://icon/" + thumb.iconName : ""
      fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; sourceSize.width: 96; sourceSize.height: 96
    }
    Icon {
      anchors.centerIn: parent; name: "bell"; size: Math.round(thumb.size * 0.42); tone: "muted"
      visible: !thumb.hasImage && thumb.iconName === ""
    }
  }
  Rectangle {
    anchors.fill: parent; radius: thumb.radius; color: "transparent"
    border.width: Tokens.hairlineWidth; border.color: Tokens.color.border
  }

  Rectangle {
    id: chip
    visible: thumb.badge && thumb.hasImage && thumb.iconName !== ""
    width: Math.round(thumb.size * 0.44); height: width; radius: width / 2
    anchors.right: parent.right; anchors.bottom: parent.bottom
    anchors.rightMargin: -Math.round(width * 0.25); anchors.bottomMargin: -Math.round(width * 0.25)
    color: Tokens.color.islandGround
    border.width: Tokens.hairlineWidth; border.color: Tokens.color.border
    Image {
      anchors.centerIn: parent; width: Math.round(chip.width * 0.66); height: width
      source: chip.visible ? "image://icon/" + thumb.iconName : ""
      fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; sourceSize.width: 64; sourceSize.height: 64
    }
  }
}
