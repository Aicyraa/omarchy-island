pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// ClickCatcher: transparent full-screen layer while a pinned or keyboard-exclusive
// widget is open, closing the widget when clicking outside Island's zoneRect.
PanelWindow {
  id: catcher
  required property var modelData
  screen: modelData
  color: "transparent"
  anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "aicyraa-island-catcher"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  visible: (IslandState.pinned || IslandState.keyboardExclusive) && IslandState.modeFor(modelData.name) === "widget"

  property bool armed: false
  onVisibleChanged: { armed = false; if (visible) armTimer.restart() }
  Timer { id: armTimer; interval: 300; onTriggered: catcher.armed = true }

  readonly property rect hole: IslandState.zoneRects[modelData.name] || Qt.rect(0, 0, 0, 0)
  mask: Region {
    item: full
    Region { item: holeItem; intersection: Intersection.Subtract }
  }
  Item { id: full; anchors.fill: parent }
  Item {
    id: holeItem
    x: catcher.hole.x; y: catcher.hole.y; width: catcher.hole.width; height: catcher.hole.height
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: if (catcher.armed) IslandState.closeWidget("click outside")
  }
}
