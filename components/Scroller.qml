import QtQuick
import ".."

// The island's own scrollbar: a slim pill (same language as the workspace indicator) that sits dim as a cue when
// there is more to see, brightens and thickens while scrolling or hovered, turns accent while dragged, and can be
// dragged or clicked (page jump). Bind it to a Flickable; it positions itself against the Flickable's own box.
Item {
  id: root
  property Flickable flick: null
  readonly property alias dragging: area.drag.active
  readonly property bool hot: dragging || area.containsMouse || (flick && (flick.moving || flick.dragging)) || recent
  property bool recent: false

  readonly property real viewH: flick ? flick.height : 0
  readonly property real contentH: flick ? flick.contentHeight : 1
  readonly property real maxY: Math.max(1, contentH - viewH)
  readonly property real margin: 4
  readonly property real trackH: Math.max(1, height - 2 * margin)
  readonly property real thumbH: Math.max(28, Math.min(trackH, trackH * viewH / contentH))
  readonly property real thumbY: margin + (trackH - thumbH) * Math.max(0, Math.min(1, flick.contentY / maxY))

  // "Recently scrolled": keeps the bar bright for a moment after the wheel stops.
  Connections { target: root.flick; function onContentYChanged() { root.recent = true; fade.restart() } }
  Timer { id: fade; interval: 900; onTriggered: root.recent = false }

  function seek(my) {
    var r = (my - margin - thumbH / 2) / Math.max(1, trackH - thumbH)
    flick.contentY = Math.max(0, Math.min(maxY, r * maxY))
  }

  Rectangle {
    id: thumb
    anchors.right: parent.right; anchors.rightMargin: 3
    y: root.thumbY; height: root.thumbH
    width: root.hot ? 6 : 4; radius: width / 2
    color: root.dragging ? Theme.accentInk : Theme.textMuted
    opacity: root.dragging ? 1 : (root.hot ? 0.85 : 0.35)
    Behavior on width { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 160 } }
    Behavior on color { ColorAnimation { duration: 140 } }
  }

  MouseArea {
    id: area
    anchors.fill: parent; hoverEnabled: true
    drag.target: dragProxy; drag.axis: Drag.YAxis       // only used to know that a drag is in progress
    onPressed: function (m) { root.seek(m.y) }
    onPositionChanged: function (m) { if (pressed) root.seek(m.y) }
    onWheel: function (w) { flick.contentY = Math.max(0, Math.min(root.maxY, flick.contentY - w.angleDelta.y * 0.5)) }
  }
  Item { id: dragProxy; visible: false }
}
