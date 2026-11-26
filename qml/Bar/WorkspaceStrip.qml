pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"

// WorkspaceStrip: Image-1-inspired workspace dots (1..5 + any extra active/existing,
// with micro gap dots when skipped) and one elongated accent gliding pill.
Item {
  id: root

  property bool vertical: false

  readonly property real dotSlotW: 16
  readonly property real gapSlotW: 12
  readonly property real slotH: 24
  readonly property real pillBaseW: 14
  readonly property real pillH: 6
  readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

  readonly property var slots: {
    var existsMap = {}
    var maxId = 5
    var wsList = Hyprland.workspaces ? Hyprland.workspaces.values : []
    for (var i = 0; i < wsList.length; i++) {
      var w = wsList[i]
      if (!w || w.id <= 0) continue
      existsMap[w.id] = true
      if (w.id > maxId) maxId = w.id
    }

    var ids = [1, 2, 3, 4, 5]
    if (activeWsId > 5) existsMap[activeWsId] = true
    for (var id = 6; id <= maxId; id++) {
      if (existsMap[id]) ids.push(id)
    }

    var out = []
    var prev = 0
    var cursorX = 0
    for (var j = 0; j < ids.length; j++) {
      var cur = ids[j]
      if (prev > 0 && cur - prev > 1) {
        out.push({ isGap: true, wsId: -cur, exists: false, active: false, x: cursorX, w: gapSlotW })
        cursorX += gapSlotW
      }
      out.push({
        isGap: false,
        wsId: cur,
        exists: !!existsMap[cur],
        active: cur === activeWsId,
        x: cursorX,
        w: dotSlotW
      })
      cursorX += dotSlotW
      prev = cur
    }
    return out
  }

  readonly property real totalWidth: slots.length > 0
    ? slots[slots.length - 1].x + slots[slots.length - 1].w
    : dotSlotW * 5

  readonly property real activeCx: {
    for (var i = 0; i < slots.length; i++) {
      if (!slots[i].isGap && slots[i].active)
        return slots[i].x + slots[i].w / 2
    }
    return dotSlotW / 2
  }

  property real headCx: activeCx
  property real tailCx: activeCx

  Behavior on headCx {
    enabled: !Tokens.reducedMotion && !Tokens.gameMode
    SpringAnimation { spring: 6.5; damping: 0.55; epsilon: 0.25 }
  }
  Behavior on tailCx {
    enabled: !Tokens.reducedMotion && !Tokens.gameMode
    SpringAnimation { spring: 3.8; damping: 0.62; epsilon: 0.25 }
  }

  implicitWidth: root.vertical ? slotH : totalWidth
  implicitHeight: root.vertical ? totalWidth : slotH

  function switchWorkspace(wsId) {
    if (Hyprland.usingLua)
      Hyprland.dispatch('hl.dsp.workspace({id=' + wsId + '})')
    else
      Hyprland.dispatch("workspace " + wsId)
  }

  function stepWorkspace(delta) {
    if (Hyprland.usingLua)
      Hyprland.dispatch(delta > 0 ? 'hl.dsp.workspace("e+1")' : 'hl.dsp.workspace("e-1")')
    else
      Hyprland.dispatch(delta > 0 ? "workspace e+1" : "workspace e-1")
  }

  function openGallery() {
    Cmd.run(["omarchy-shell", "-q", "io.github.aicyraa.workspace-gallery.perspective", "toggle"])
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) {
      if (event.angleDelta.y > 0) root.stepWorkspace(-1)
      else if (event.angleDelta.y < 0) root.stepWorkspace(1)
      event.accepted = true
    }
  }

  // Workspace dots & gap indicators
  Repeater {
    model: root.slots

    delegate: Item {
      id: slotItem
      required property var modelData
      required property int index

      x: root.vertical ? 0 : modelData.x
      y: root.vertical ? modelData.x : 0
      width: root.vertical ? root.slotH : modelData.w
      height: root.vertical ? modelData.w : root.slotH

      readonly property bool hovered: slotMouse.containsMouse

      // Micro "..." gap dots when workspaces > 5 have skipped IDs
      Row {
        anchors.centerIn: parent
        spacing: 2
        visible: slotItem.modelData.isGap

        Repeater {
          model: 3
          delegate: Rectangle {
            width: 2
            height: 2
            radius: 1
            color: Tokens.color.textMuted
            opacity: 0.55
          }
        }
      }

      // Workspace dot
      Rectangle {
        anchors.centerIn: parent
        visible: !slotItem.modelData.isGap
        width: slotItem.hovered ? 7 : 5
        height: slotItem.hovered ? 7 : 5
        radius: width / 2
        color: slotItem.modelData.exists ? Tokens.color.textSecondary : Tokens.color.textMuted
        opacity: slotItem.modelData.active ? 0 : (slotItem.modelData.exists ? 0.85 : 0.38)

        Behavior on width {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
        }
        Behavior on height {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
        }
        Behavior on opacity {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
        }
      }

      FocusRing {
        active: slotItem.activeFocus
        ringRadius: Tokens.radius.pill
      }

      activeFocusOnTab: !modelData.isGap
      Accessible.role: modelData.isGap ? Accessible.NoRole : Accessible.Button
      Accessible.name: modelData.isGap ? "" : qsTr("Workspace %1").arg(modelData.wsId)
      Accessible.ignored: modelData.isGap

      Keys.onSpacePressed: function(e) {
        if (!slotItem.modelData.isGap) {
          root.switchWorkspace(slotItem.modelData.wsId)
          e.accepted = true
        }
      }
      Keys.onReturnPressed: function(e) {
        if (!slotItem.modelData.isGap) {
          root.switchWorkspace(slotItem.modelData.wsId)
          e.accepted = true
        }
      }

      MouseArea {
        id: slotMouse
        anchors.fill: parent
        hoverEnabled: !slotItem.modelData.isGap
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: slotItem.modelData.isGap ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (slotItem.modelData.isGap) {
            root.openGallery()
            return
          }
          if (mouse.button === Qt.RightButton || slotItem.modelData.active)
            root.openGallery()
          else
            root.switchWorkspace(slotItem.modelData.wsId)
        }
      }
    }
  }

  // Gliding accent pill
  Rectangle {
    id: activePill
    z: 2
    x: root.vertical ? (root.slotH - root.pillH) / 2 : (Math.min(root.headCx, root.tailCx) - root.pillBaseW / 2)
    y: root.vertical ? (Math.min(root.headCx, root.tailCx) - root.pillBaseW / 2) : ((root.slotH - root.pillH) / 2)
    width: root.vertical ? root.pillH : (Math.abs(root.headCx - root.tailCx) + root.pillBaseW)
    height: root.vertical ? (Math.abs(root.headCx - root.tailCx) + root.pillBaseW) : root.pillH
    radius: root.pillH / 2
    color: Tokens.color.accent
    Accessible.ignored: true
  }
}
