import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "."
import "services"
import "widgets/Registry.js" as Registry

// One Island per screen (created by Variants in Bar.qml).
//
// IMPORTANT DESIGN RULE: the PanelWindow is a FIXED size (big enough for the
// largest widget) and transparent. We never animate the window's size: every
// size change makes the compositor re-configure the layer surface, which
// stutters. Instead only the inner `pill` Rectangle animates, and `mask`
// tells the compositor that clicks outside the pill fall through to the apps
// underneath.
PanelWindow {
  id: win

  required property var modelData      // injected by Variants: a ShellScreen
  property bool rig: false             // test rig: don't reserve screen space

  screen: modelData
  readonly property string screenName: modelData.name
  // What THIS screen shows right now (idle on every screen unless it owns the
  // widget/HUD/hover).
  readonly property string myMode: IslandState.modeFor(screenName)

  // ---- geometry (pill size per mode) ----
  readonly property int topMargin: 6
  function sizeFor(m) {
    switch (m) {
    case "hover":        return Qt.size(560, 46)
    case "widget":       return Qt.size(Registry.width(IslandState.widgetName),
                                        Registry.height(IslandState.widgetName) + (IslandState.hintsVisible ? 26 : 0))
    case "hud":          return Qt.size(300, 44)
    case "notification": return Qt.size(420, 52)
    default:             return Qt.size(250, 32)     // idle
    }
  }
  readonly property size target: sizeFor(myMode)
  readonly property size idleSize: sizeFor("idle")

  color: "transparent"
  anchors.top: true                     // top edge only -> centered horizontally
  implicitWidth: 760
  implicitHeight: 480
  // Reserve exactly the collapsed height so tiled windows don't jump when the
  // pill grows (it overlays windows instead).
  exclusionMode: rig ? ExclusionMode.Ignore : ExclusionMode.Normal
  exclusiveZone: topMargin + idleSize.height

  WlrLayershell.namespace: "aicyraa-island"
  // Only grab the keyboard while a widget is open on this screen.
  WlrLayershell.keyboardFocus: myMode === "widget" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // Hide in fullscreen unless the user explicitly opened a widget.
  visible: !(IslandState.fullscreen && myMode !== "widget")

  // Click-outside closes a widget: while open, a focus grab watches for a click
  // elsewhere and reports `cleared`.
  HyprlandFocusGrab {
    windows: [win]
    active: win.myMode === "widget"
    onCleared: IslandState.closeWidget()
  }

  // ---- input region ----
  // `zone` is the hover target and the clickable area. It is always at least
  // as big as the pill's TARGET size (plus margin), which "bridges" the gap
  // while the pill is mid-spring, so moving into the expanded pill never
  // counts as leaving.
  mask: Region { item: zone }
  Item {
    id: zone
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: win.target.width + 20
    height: win.topMargin + win.target.height + 8
    HoverHandler { onHoveredChanged: IslandState.hoverIntent(hovered, win.screenName) }
  }

  // ---- the morphing pill ----
  // Width leads, height follows ~40ms later: `height` springs toward
  // `delayedH`, which a 40ms timer copies from the real target. That is
  // imperative code on purpose; a pure binding can't express "later".
  property real delayedH: target.height
  onTargetChanged: {
    if (IslandState.reducedMotion) delayedH = target.height
    else heightGate.restart()
  }
  Timer { id: heightGate; interval: 40; onTriggered: win.delayedH = win.target.height }

  Rectangle {
    id: pill
    y: win.topMargin
    anchors.horizontalCenter: parent.horizontalCenter
    width: win.target.width
    height: win.delayedH
    radius: Math.min(height / 2, 24)
    color: Theme.pill
    clip: true                           // content never spills while resizing

    // SpringAnimation: `spring` = stiffness, `damping` = how fast bounce dies,
    // `epsilon` = stop threshold. See README tuning cheat sheet.
    Behavior on width {
      enabled: !IslandState.reducedMotion
      SpringAnimation { spring: 3.4; damping: 0.26; epsilon: 0.5 }
    }
    Behavior on height {
      enabled: !IslandState.reducedMotion
      SpringAnimation { spring: 3.0; damping: 0.28; epsilon: 0.5 }
    }

    // ---- content, crossfaded in two beats ----
    // The content item has the TARGET size and is pinned to the top-center, so
    // it never visibly squishes while the pill springs around it.
    property string shownMode: "idle"
    Item {
      id: content
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: win.sizeFor(pill.shownMode).width
      height: win.sizeFor(pill.shownMode).height
      focus: win.myMode === "widget"
      // BeforeItem: we see every key first (to reset the inactivity timer and
      // handle Esc and "?"), then unhandled keys fall through to the widget.
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function (e) {
        IslandState.touch(true)
        // A widget may claim Esc for its own sub-mode (e.g. closing a search box)
        // by exposing `capturesEscape: true`; otherwise Esc closes the widget.
        var claimed = widgetLoader.item && widgetLoader.item.capturesEscape === true
        if (e.key === Qt.Key_Escape && !claimed) { IslandState.closeWidget(); e.accepted = true }
        else if (e.text === "?") { IslandState.hintsVisible = !IslandState.hintsVisible; e.accepted = true }
      }

      // Beat 1: old content fades out fast (80ms). Beat 2: swap, new fades in.
      // Restarting mid-flight is safe: the fade-out starts from the CURRENT
      // opacity, so rapid mode changes never leave stale content.
      SequentialAnimation {
        id: swap
        NumberAnimation { target: content; property: "opacity"; to: 0
          duration: IslandState.reducedMotion ? 0 : 80 }
        ScriptAction { script: pill.shownMode = win.myMode }
        NumberAnimation { target: content; property: "opacity"; to: 1
          duration: IslandState.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic }
      }
      Connections { target: win; function onMyModeChanged() { swap.restart() } }

      // ---------- idle + hover form ----------
      Item {
        anchors.fill: parent
        visible: pill.shownMode === "idle" || pill.shownMode === "hover"
        readonly property bool expanded: pill.shownMode === "hover"

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Column {                                   // left: title + workspaces
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Text {
            visible: parent.parent.expanded
            width: 170
            elide: Text.ElideRight
            textFormat: Text.PlainText       // window titles are untrusted text
            text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ""
            color: Theme.textMuted
            font.pixelSize: 11
          }
          Workspaces { }
        }

        Row {                                      // center: time (+ date)
          anchors.centerIn: parent
          spacing: 8
          Text {
            textFormat: Text.PlainText
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.pixelSize: 14; font.bold: true
            TapHandler { onTapped: IslandState.toggleWidget("calendar") }
          }
          Text {
            visible: parent.parent.expanded
            textFormat: Text.PlainText
            text: Qt.formatDateTime(clock.date, "ddd, MMM d")
            color: Theme.textMuted
            font.pixelSize: 12
            anchors.baseline: undefined
          }
        }

        Row {                                      // right: status
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10
          Text {                                   // placeholder until the notification service is wired (milestone 3)
            visible: parent.parent.expanded
            textFormat: Text.PlainText
            text: "All caught up"
            color: Theme.textMuted
            font.pixelSize: 11
          }
          WifiBars { anchors.verticalCenter: parent.verticalCenter }
          BatteryIcon { anchors.verticalCenter: parent.verticalCenter }
        }
      }

      // ---------- HUD form (volume / brightness / ...) ----------
      Item {
        anchors.fill: parent
        visible: pill.shownMode === "hud"
        // Number "ticks" toward the target instead of snapping.
        property real shown: IslandState.hudValue
        Behavior on shown { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }
        Text {
          anchors.left: parent.left; anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          width: IslandState.hudMessage !== "" ? 260 : 90
          elide: Text.ElideRight
          text: IslandState.hudMessage !== "" ? IslandState.hudMessage : IslandState.hudLabel(IslandState.hudKind)
          color: Theme.text; font.pixelSize: 12
        }
        Row {
          visible: IslandState.hudMessage === ""
          anchors.right: parent.right; anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10
          Rectangle {
            width: 160; height: 8; radius: 4; color: Theme.surfaceRaised
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, parent.parent.parent.shown / 100))
              height: parent.height; radius: 4; color: Theme.accent
            }
          }
          Text {
            width: 30; horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: Math.round(parent.parent.shown) + "%"
            color: Theme.text; font.pixelSize: 12; font.bold: true
          }
        }
      }

      // ---------- widget host ----------
      // `active` is only true while a widget is on screen, so a closed widget
      // is fully unloaded: its Timers and Processes are destroyed with it.
      Loader {
        id: widgetLoader
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: win.sizeFor("widget").width
        height: Registry.height(IslandState.widgetName)
        active: pill.shownMode === "widget"
        focus: true
        source: active ? "widgets/" + Registry.fileOf(IslandState.widgetName) : ""
        onLoaded: {
          item.forceActiveFocus()
          // Widgets that need the window (e.g. tray context menus) declare `hostWindow`.
          if (item.hasOwnProperty("hostWindow")) item.hostWindow = win
        }
      }
      // Hint row (toggle with "?").
      Text {
        visible: pill.shownMode === "widget" && IslandState.hintsVisible
        anchors.bottom: parent.bottom; anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: widgetLoader.item && widgetLoader.item.hint ? widgetLoader.item.hint : ""
        color: Theme.textMuted; font.pixelSize: 11
      }
    }
  }
}
