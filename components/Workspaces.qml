import QtQuick
import Quickshell
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

  // Workspaces to show: the ones that exist (Hyprland keeps occupied and focused ones), sorted; the focused one is always
  // included, so going to an empty workspace 4 adds a dot for it. Where the numbering skips (1 2 3 then 8), a small
  // "..." marker stands for the missing ones, so you can tell you are far away without a long row of dots.
  // ISLAND_FAKE_WS="1,2,3,8" and ISLAND_FAKE_FOCUS=8 feed fake data (testing).
  readonly property var realIds: {
    var fake = Quickshell.env("ISLAND_FAKE_WS")
    if (fake) return fake.split(",").map(Number)
    var out = []
    var ws = Hyprland.workspaces.values
    for (var i = 0; i < ws.length; i++) if (ws[i].id > 0) out.push(ws[i].id)
    return out
  }
  readonly property int focusedId: Quickshell.env("ISLAND_FAKE_FOCUS") ? Number(Quickshell.env("ISLAND_FAKE_FOCUS"))
                                    : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
  readonly property var ids: {
    var out = realIds.slice()
    if (focusedId > 0 && out.indexOf(focusedId) < 0) out.push(focusedId)
    if (out.length === 0) out.push(1)
    out.sort(function (a, b) { return a - b })
    return out
  }
  // Slots: { id } for a workspace, { gap: true } for a "..." marker between non-consecutive ids.
  readonly property var items: {
    var out = []
    for (var i = 0; i < ids.length; i++) {
      if (i > 0 && ids[i] - ids[i - 1] > 1) out.push({ gap: true, id: -1 })
      out.push({ gap: false, id: ids[i] })
    }
    return out
  }

  implicitWidth: items.length * slot
  implicitHeight: capH                  // room for the tall pill, so the layout never shifts when focus moves

  Repeater {
    model: root.items
    delegate: Item {
      required property var modelData
      required property int index
      readonly property bool gap: modelData.gap
      readonly property bool active: !gap && modelData.id === root.focusedId
      x: index * root.slot; width: root.slot; height: parent.height

      // a workspace: dot, or the tall pill when focused
      Rectangle {
        visible: !parent.gap
        antialiasing: true
        x: (root.slot - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: parent.active ? root.activeW : root.dot
        height: parent.active ? root.capH : root.dot
        radius: width / 2
        color: parent.active ? Theme.text : Theme.textMuted
        opacity: parent.active ? 1 : 0.55
        // Height is the stretch: a spring (stiff, slightly bouncy). Width and colour just ease.
        Behavior on height {
          enabled: !IslandState.reducedMotion
          SpringAnimation { spring: 4.5; damping: 0.30; epsilon: 0.2 }
        }
        Behavior on width { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }
      // skipped workspaces: three tiny dots
      Row {
        visible: parent.gap
        anchors.centerIn: parent; spacing: 1.5
        Repeater { model: 3
          Rectangle { antialiasing: true; width: 2; height: 2; radius: 1; color: Theme.textMuted; opacity: 0.5 } }
      }
    }
  }

  // Click a slot to switch; scroll anywhere to step through workspaces.
  MouseArea {
    anchors.fill: parent; anchors.margins: -4       // larger hit area than the 5px dots
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onClicked: function (m) {
      var i = Math.floor((m.x + 4) / root.slot)
      if (i >= 0 && i < root.items.length && !root.items[i].gap) Hyprland.dispatch("workspace " + root.items[i].id)
    }
    onWheel: function (w) { Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1") }
  }
}
