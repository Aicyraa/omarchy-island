import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

// Workspace indicator.
//   * Always shows workspaces 1-5 as dots. Workspaces beyond 5 that exist (or that you are on) are appended, and where
//     the numbering skips a small "..." marker stands for the missing ones: 1 2 3 4 5 ... 8.
//   * The focused workspace is ONE short pill that glides from dot to dot. Its leading edge moves on a quick spring and
//     its trailing edge on a slower one, so it stretches while it travels and then settles (a liquid hand-over).
//   * New slots scale in; slots slide aside when a marker appears.
// ISLAND_FAKE_WS="1,2,3,8" and ISLAND_FAKE_FOCUS=8 feed fake data (testing).
Item {
  id: root

  readonly property int slot: 11        // width of one slot
  readonly property int dot: 5          // resting diameter
  readonly property int activeW: 6      // the focused pill's width at rest
  readonly property int capH: 10        // the focused pill's height (short: it sits easily in the 20 px capsule)
  readonly property int baseCount: 5

  readonly property var realIds: {
    var fake = Quickshell.env("ISLAND_FAKE_WS")
    if (fake) return fake.split(",").map(Number)
    var out = []
    var ws = Hyprland.workspaces.values
    for (var i = 0; i < ws.length; i++) if (ws[i].id > 0) out.push(ws[i].id)
    return out
  }
  property int focusOverride: 0         // test hook: pretend this workspace is focused
  readonly property int focusedId: focusOverride > 0 ? focusOverride : Quickshell.env("ISLAND_FAKE_FOCUS") ? Number(Quickshell.env("ISLAND_FAKE_FOCUS"))
                                    : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
  readonly property var ids: {
    var out = []
    for (var n = 1; n <= baseCount; n++) out.push(n)
    realIds.forEach(function (id) { if (id > baseCount && out.indexOf(id) < 0) out.push(id) })
    if (focusedId > 0 && out.indexOf(focusedId) < 0) out.push(focusedId)
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
  readonly property int focusIndex: {
    for (var i = 0; i < items.length; i++) if (!items[i].gap && items[i].id === focusedId) return i
    return 0
  }

  implicitWidth: items.length * slot
  implicitHeight: 14

  // ---- the dots ----
  Repeater {
    model: root.items
    delegate: Item {
      id: cell
      required property var modelData
      required property int index
      readonly property bool gap: modelData.gap
      readonly property bool focused: !gap && modelData.id === root.focusedId
      width: root.slot; height: root.implicitHeight
      x: index * root.slot
      Behavior on x { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      // scale in when a slot is added
      property real appear: 0
      Component.onCompleted: appear = 1
      Behavior on appear { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
      scale: IslandState.reducedMotion ? 1 : appear

      Rectangle {
        visible: !cell.gap
        antialiasing: true
        anchors.centerIn: parent
        width: root.dot; height: root.dot; radius: width / 2
        color: Theme.textMuted
        // the focused slot's dot gives way to the gliding pill
        opacity: cell.focused ? 0 : 0.55
        scale: cell.focused ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { enabled: !IslandState.reducedMotion; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      }
      Row {
        visible: cell.gap
        anchors.centerIn: parent; spacing: 1.5
        Repeater { model: 3
          Rectangle { antialiasing: true; width: 2; height: 2; radius: 1; color: Theme.textMuted; opacity: 0.5 } }
      }
    }
  }

  // ---- the gliding focus pill: head (leading edge) and tail (trailing edge) chase the focused slot's centre ----
  readonly property real targetCx: focusIndex * slot + slot / 2
  property real headCx: targetCx
  property real tailCx: targetCx
  property bool ready: false
  Component.onCompleted: Qt.callLater(function () { root.ready = true })
  Behavior on headCx { enabled: root.ready && !IslandState.reducedMotion; SpringAnimation { spring: 6.5; damping: 0.42; epsilon: 0.05 } }
  Behavior on tailCx { enabled: root.ready && !IslandState.reducedMotion; SpringAnimation { spring: 3.6; damping: 0.50; epsilon: 0.05 } }
  Rectangle {
    antialiasing: true
    height: root.capH; radius: height / 2
    anchors.verticalCenter: parent.verticalCenter
    color: Theme.text
    x: Math.min(root.headCx, root.tailCx) - root.activeW / 2
    width: Math.abs(root.headCx - root.tailCx) + root.activeW
  }

  // Hyprland here runs its Lua config, so dispatchers use the hl.dsp syntax (the legacy "workspace N" is ignored).
  function focusWorkspace(target) {
    Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({workspace="' + target + '"})' : "workspace " + target)
  }

  // Click a slot to switch; scroll anywhere to step through workspaces.
  MouseArea {
    anchors.fill: parent; anchors.margins: -4       // larger hit area than the 5px dots
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onClicked: function (m) {
      // m.x is in this area's coordinates, which start 4 px left of the item
      var i = Math.floor((m.x - 4) / root.slot)
      if (i >= 0 && i < root.items.length && !root.items[i].gap) root.focusWorkspace(root.items[i].id)
    }
    onWheel: function (w) { root.focusWorkspace(w.angleDelta.y > 0 ? "e-1" : "e+1") }
  }
}
