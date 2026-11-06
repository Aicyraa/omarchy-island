import QtQuick
import Quickshell.Hyprland
import ".."

// Workspace dots with a "liquid" capsule for the focused one.
//
// The capsule is drawn from two edges, left (l) and right (r), each driven by
// its own spring. The LEADING edge (the one in the direction of travel) gets a
// stiff, fast spring and the TRAILING edge a softer one, so the capsule
// stretches toward the target and then catches up, like a drop of liquid.
Item {
  id: root

  readonly property int slot: 12        // width of one workspace slot
  readonly property int dot: 5
  readonly property int capW: 17        // capsule width (centered on its slot)

  // Workspaces to show: all real ones (id > 0), sorted, with a minimum of 4 so
  // the idle pill isn't empty on a fresh session.
  readonly property var ids: {
    var out = []
    var ws = Hyprland.workspaces.values
    for (var i = 0; i < ws.length; i++) if (ws[i].id > 0) out.push(ws[i].id)
    out.sort(function (a, b) { return a - b })
    var max = out.length ? out[out.length - 1] : 0
    for (var n = 1; n <= Math.max(4, max) && out.length < 4; n++)
      if (out.indexOf(n) < 0) out.push(n)
    out.sort(function (a, b) { return a - b })
    return out
  }
  readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  readonly property int focusedSlot: Math.max(0, ids.indexOf(focusedId))

  implicitWidth: ids.length * slot
  implicitHeight: dot          // exactly the ink height, so a stacked layout stays vertically symmetric

  // Target edges for the capsule.
  readonly property real tl: focusedSlot * slot + (slot - capW) / 2
  readonly property real tr: tl + capW
  property real l: tl
  property real r: tr
  // Which way are we moving? Compared against the previous target.
  property bool movingRight: true
  property real prevTl: tl
  onTlChanged: { movingRight = tl > prevTl; prevTl = tl }

  Behavior on l {
    enabled: !IslandState.reducedMotion
    SpringAnimation { spring: root.movingRight ? 2.0 : 5.0; damping: root.movingRight ? 0.30 : 0.38; epsilon: 0.25 }
  }
  Behavior on r {
    enabled: !IslandState.reducedMotion
    SpringAnimation { spring: root.movingRight ? 5.0 : 2.0; damping: root.movingRight ? 0.38 : 0.30; epsilon: 0.25 }
  }

  Repeater {
    model: root.ids
    delegate: Rectangle {
      required property int modelData
      required property int index
      x: index * root.slot + (root.slot - root.dot) / 2
      anchors.verticalCenter: parent.verticalCenter
      width: root.dot; height: root.dot; radius: root.dot / 2
      color: Theme.textMuted
      opacity: 0.55
    }
  }

  Rectangle {                           // the capsule
    x: Math.min(root.l, root.r)
    width: Math.abs(root.r - root.l)
    anchors.verticalCenter: parent.verticalCenter
    height: root.dot
    radius: height / 2
    color: Theme.text
  }

  // Click a slot to switch; scroll anywhere to step through workspaces.
  MouseArea {
    anchors.fill: parent; anchors.margins: -4       // larger hit area than the 5px dots
    onClicked: function (m) {
      var i = Math.floor(m.x / root.slot)
      if (i >= 0 && i < root.ids.length) Hyprland.dispatch("workspace " + root.ids[i])
    }
    onWheel: function (w) { Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1") }
  }
}
