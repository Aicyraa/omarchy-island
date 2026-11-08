import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// A transparent, full-screen layer that exists only while a KEYBIND-opened (pinned) widget is open on this screen.
// A press anywhere outside the island closes the widget: that is a real click, which is what the focus grab could not
// tell apart from keyboard focus moving to another window. The press is consumed, as for most popups.
// It sits under the island window (the island is created after it, so it is stacked above it on the same layer).
PanelWindow {
  id: catcher
  required property var modelData
  screen: modelData
  color: "transparent"
  anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "aicyraa-island-catcher"
  // Overlay, above the dock and the bar, so a click on them outside the island counts as outside. The island has a hole.
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  visible: IslandState.pinned && IslandState.modeFor(modelData.name) === "widget"

  // A stray press can arrive as the layer appears (the keypress that opened the widget is not a click): ignore anything
  // for 300 ms after it appears, and count only a complete click, a press AND release on the catcher.
  property bool armed: false
  onVisibleChanged: { armed = false; if (visible) armTimer.restart() }
  Timer { id: armTimer; interval: 300; onTriggered: catcher.armed = true }

  // The input region: the whole screen, minus the island's zone (a hole), so the island keeps every click on it.
  readonly property var hole: IslandState.zoneRects[modelData.name] || Qt.rect(0, 0, 0, 0)
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
