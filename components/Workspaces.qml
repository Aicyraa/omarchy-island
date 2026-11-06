import QtQuick
import Quickshell.Hyprland
import ".."

// Workspace indicator: one small dot per workspace; the FOCUSED one stretches
// VERTICALLY into a tall pill (taller, not wider, so the row stays compact and
// fits inside the bar's height).
//
// Each dot owns its own shape, and the stretch is a spring on its height: when
// focus moves, the old pill springs back down to a dot while the new one springs
// up, so the two motions overlap like a liquid handing over. Slots never move.
Item {
  id: root

  readonly property int slot: 11        // width of one workspace slot
  readonly property int dot: 5          // resting diameter
  readonly property int activeW: 6      // the focused pill is a touch wider than a dot
  readonly property int capH: 14        // the focused pill's height (fits the 26px idle bar with 6px to spare)

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

  implicitWidth: ids.length * slot
  implicitHeight: capH                  // room for the tall pill, so the layout never shifts when focus moves

  Repeater {
    model: root.ids
    delegate: Rectangle {
      required property int modelData
      required property int index
      readonly property bool active: modelData === root.focusedId
      x: index * root.slot + (root.slot - width) / 2
      anchors.verticalCenter: parent.verticalCenter
      width: active ? root.activeW : root.dot
      height: active ? root.capH : root.dot
      radius: width / 2
      color: active ? Theme.text : Theme.textMuted
      opacity: active ? 1 : 0.55

      // Height is the stretch: a spring (stiff, slightly bouncy). Width and colour just ease.
      Behavior on height {
        enabled: !IslandState.reducedMotion
        SpringAnimation { spring: 4.5; damping: 0.30; epsilon: 0.2 }
      }
      Behavior on width { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 200 } }
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }
  }

  // Click a slot to switch; scroll anywhere to step through workspaces.
  MouseArea {
    anchors.fill: parent; anchors.margins: -4       // larger hit area than the 5px dots
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onClicked: function (m) {
      var i = Math.floor((m.x + 4) / root.slot)
      if (i >= 0 && i < root.ids.length) Hyprland.dispatch("workspace " + root.ids[i])
    }
    onWheel: function (w) { Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1") }
  }
}
