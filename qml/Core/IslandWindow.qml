pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "."
import "Visuals"
import "../Bar"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "WidgetRegistry.js" as Registry

// IslandWindow: one per screen. Full-height transparent PanelWindow when detached
// ScrollRail or centered Spotlight menu is needed, masked to exact pill + ScrollRail
// Regions so everything else passes clicks straight through.
PanelWindow {
  id: win

  required property var modelData
  property bool rig: false

  screen: modelData
  readonly property string screenName: modelData.name

  readonly property string globalMode: IslandState.mode
  readonly property string myMode:
    globalMode === "idle" ? "idle" : (screenName === IslandState.activeScreen ? globalMode : "idle")

  readonly property bool isBottom: ConfigStore.barPosition === "bottom"
  readonly property bool isNotch: ConfigStore.barStyle === "notch"
  readonly property bool isFullBar: ConfigStore.barStyle === "full"
  readonly property bool isSpotlightMenu: myMode === "widget" && IslandState.widgetName === "menu" && ConfigStore.menuPresentation === "spotlight"

  readonly property bool detachedMode: myMode === "widget" || myMode === "hud" || myMode === "notification" || !isNotch
  readonly property int topGap: 6
  readonly property int barHeight: 36
  readonly property int ear: 12

  function savedHeight(name) {
    var m = Cache.get("wsize")
    return (m && m[name]) ? m[name] : 0
  }

  function widgetSizeOf(name) {
    var it = widgetLoader.item
    if (it && pill.shownWidget === name && it.implicitHeight > 0)
      return Qt.size(Math.min(Tokens.px(940), it.implicitWidth), it.implicitHeight)
    var saved = (name === "wifi") ? 0 : savedHeight(name)
    return Qt.size(Registry.width(name), saved > 0 ? saved : Registry.height(name))
  }

  function sizeFor(m) {
    switch (m) {
    case "widget":       return widgetSizeOf(IslandState.widgetName)
    case "hud":          return Qt.size(300, 44)
    case "notification": return Qt.size(420, 68)
    default:
      var w = isFullBar && win.screen ? Math.max(320, win.screen.width - 2 * Tokens.compositorGapsOut) : topBar.widthFor()
      return Qt.size(w, win.barHeight)
    }
  }

  readonly property size target: sizeFor(myMode)
  readonly property size shownSize: pill.shownMode === "widget" ? widgetSizeOf(pill.shownWidget) : sizeFor(pill.shownMode)
  readonly property size idleSize: sizeFor("idle")

  function pillBox() {
    return Qt.size(target.width + 2 * ear, target.height + topGap)
  }

  Component.onCompleted: {
    IslandState.islands[screenName] = win
    IslandState.setZone(screenName, zoneRect)
  }
  Component.onDestruction: delete IslandState.islands[screenName]

  color: "transparent"
  anchors.top: !win.isBottom
  anchors.bottom: win.isBottom
  anchors.left: true
  anchors.right: true
  implicitHeight: win.screen ? win.screen.height : 1080
  exclusionMode: rig ? ExclusionMode.Ignore : ExclusionMode.Normal
  exclusiveZone: win.rig ? 0 : Math.max(0, win.barHeight + win.topGap - Tokens.compositorGapsOut)

  WlrLayershell.namespace: "aicyraa-island"
  WlrLayershell.layer: WlrLayer.Top

  readonly property bool needsKeyboard: myMode === "widget" && widgetLoader.item !== null && widgetLoader.item !== undefined && widgetLoader.item.wantsKeyboard === true
  onNeedsKeyboardChanged: if (screenName === IslandState.activeScreen || !needsKeyboard) IslandState.keyboardExclusive = needsKeyboard
  WlrLayershell.keyboardFocus: needsKeyboard ? WlrKeyboardFocus.Exclusive : (myMode === "widget" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

  visible: !IslandState.barHidden && !IslandState.screensaver && !(ConfigStore.hideInFullscreen && IslandState.fullscreen && myMode !== "widget")

  property bool grabHold: false
  property bool menuArmed: false
  Timer { id: menuArm; interval: 700; onTriggered: win.menuArmed = true }
  Connections {
    target: IslandState
    function onWidgetNameChanged() {
      win.menuArmed = false
      if (IslandState.widgetName === "menu") menuArm.restart()
      else menuArm.stop()
    }
  }

  HyprlandFocusGrab {
    windows: [win]
    active: win.myMode === "widget" && !win.grabHold && !win.needsKeyboard && (!IslandState.pinned || (IslandState.widgetName === "menu" && win.menuArmed))
    onCleared: if (IslandState.pinned && IslandState.widgetName !== "menu") {
    } else {
      IslandState.guard("focus grab cleared", function (stayed) {
        if (stayed) {
          win.grabHold = true
          Qt.callLater(function () { win.grabHold = false })
        }
      })
    }
  }

  // ---- Input region: exact pill + detached ScrollRail ----
  readonly property rect zoneRect: Qt.rect(
    Math.round(Math.min(pill.x - (win.isNotch && !win.detachedMode ? win.ear : 0), rail.needed ? rail.inputRect.x : pill.x)),
    Math.round(Math.min(pill.y, rail.needed ? rail.inputRect.y : pill.y)),
    Math.round(Math.max(pill.x + pill.width + (win.isNotch && !win.detachedMode ? win.ear : 0), rail.needed ? rail.inputRect.x + rail.inputRect.width : pill.x + pill.width) - Math.min(pill.x - (win.isNotch && !win.detachedMode ? win.ear : 0), rail.needed ? rail.inputRect.x : pill.x)),
    Math.round(Math.max(pill.y + pill.height, rail.needed ? rail.inputRect.y + rail.inputRect.height : pill.y + pill.height) - Math.min(pill.y, rail.needed ? rail.inputRect.y : pill.y))
  )
  onZoneRectChanged: IslandState.setZone(screenName, zoneRect)

  mask: Region {
    Region {
      x: Math.round(pill.x - (win.isNotch && !win.detachedMode ? win.ear : 0))
      y: Math.round(pill.y)
      width: Math.round(pill.width + (win.isNotch && !win.detachedMode ? 2 * win.ear : 0))
      height: Math.round(pill.height)
    }
    Region {
      x: Math.round(rail.inputRect.x)
      y: Math.round(rail.inputRect.y)
      width: Math.round(rail.inputRect.width)
      height: Math.round(rail.inputRect.height)
    }
  }

  // ---- Debug measure ----
  function walk(item, out, depth) {
    var ch = item.children
    for (var i = 0; i < ch.length; i++) {
      var c = ch[i]
      if (!c.visible || c.opacity <= 0.01 || c.width <= 0 || c.height <= 0) continue
      var p = c.mapToItem(pill, 0, 0)
      var kind = "item", w = c.width, h = c.height, x = p.x
      if (c.contentWidth !== undefined && c.text !== undefined) {
        kind = "text"; w = Math.min(c.contentWidth, c.width); h = c.contentHeight
        if (c.horizontalAlignment === Text.AlignRight) x = p.x + c.width - w
        else if (c.horizontalAlignment === Text.AlignHCenter) x = p.x + (c.width - w) / 2
      } else if (c.preferredRendererType !== undefined && c.isBgSurface !== true) {
        kind = "shape"; w = c.width * c.scale; h = c.height * c.scale
      } else if (c.radius !== undefined && c.isBgSurface !== true && c.children.length === 0 && c.width <= 40 && c.height <= 40) {
        kind = "shape"
      } else if (c.paintedWidth !== undefined) {
        kind = "image"; w = c.paintedWidth; h = c.paintedHeight
      }
      out.push({ x: x, y: p.y, w: w, h: h, kind: kind, name: c.objectName || "" })
      if (depth < 9) walk(c, out, depth + 1)
    }
  }

  function measure() {
    var all = []; walk(content, all, 0)
    var ink = all.filter(function (r) { return r.kind === "text" || r.kind === "shape" || r.kind === "image" })
    var L = 1e9, T = 1e9, R = -1e9, B = -1e9, over = []
    ink.forEach(function (r) {
      if (r.y >= pill.height || r.y + r.h <= 0) return
      L = Math.min(L, r.x); T = Math.min(T, r.y); R = Math.max(R, r.x + r.w); B = Math.max(B, r.y + r.h)
      if (r.x < -0.5 || r.x + r.w > pill.width + 0.5) over.push(r)
    })
    var clock = all.filter(function (r) { return r.name === "clockText" })[0]
    return JSON.stringify({
      mode: myMode,
      widget: IslandState.widgetName,
      pill: { w: Math.round(pill.width), h: Math.round(pill.height), tw: Math.round(win.target.width), th: Math.round(win.target.height) },
      content: ink.length ? { l: Math.round(L), t: Math.round(T), r: Math.round(R), b: Math.round(B) } : null,
      pad: ink.length ? { top: Math.round(T), left: Math.round(L), right: Math.round(pill.width - R), bottom: Math.round(pill.height - B) } : null,
      overflowX: over.length,
      railNeeded: rail.needed,
      reveal: { shown: pill.shownMode, fade: +content.fade.toFixed(2), fit: +pill.fit.toFixed(2), opacity: +content.opacity.toFixed(2) },
      clockDX: clock ? +((clock.x + clock.w / 2) - pill.width / 2).toFixed(1) : null,
      items: all.length
    })
  }

  Connections {
    target: IslandState
    function onMeasureRequested() {
      if (win.myMode !== "idle" || win.screenName === IslandState.focusedScreenName())
        IslandState.measureResult = win.measure()
    }
  }

  // ---- Concave notch ears (only when barStyle === "notch" and in idle) ----
  Shape {
    z: 3
    opacity: win.isNotch && win.myMode === "idle" ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { enabled: !Tokens.reducedMotion && !Tokens.gameMode; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    x: pill.x - win.ear
    y: win.isBottom ? pill.y + pill.height - win.ear : pill.y
    width: win.ear; height: win.ear
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Tokens.groundOf(Tokens.surfaceStyle); strokeWidth: 0; strokeColor: "transparent"
      startX: 0; startY: win.isBottom ? win.ear : 0
      PathQuad { x: win.ear; y: win.isBottom ? 0 : win.ear; controlX: win.ear; controlY: win.isBottom ? win.ear : 0 }
      PathLine { x: win.ear; y: win.isBottom ? win.ear : 0 }
      PathLine { x: 0; y: win.isBottom ? win.ear : 0 }
    }
  }

  Shape {
    z: 3
    opacity: win.isNotch && win.myMode === "idle" ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { enabled: !Tokens.reducedMotion && !Tokens.gameMode; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    x: pill.x + pill.width
    y: win.isBottom ? pill.y + pill.height - win.ear : pill.y
    width: win.ear; height: win.ear
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Tokens.groundOf(Tokens.surfaceStyle); strokeWidth: 0; strokeColor: "transparent"
      startX: win.ear; startY: win.isBottom ? win.ear : 0
      PathQuad { x: 0; y: win.isBottom ? 0 : win.ear; controlX: 0; controlY: win.isBottom ? win.ear : 0 }
      PathLine { x: 0; y: win.isBottom ? win.ear : 0 }
      PathLine { x: win.ear; y: win.isBottom ? win.ear : 0 }
    }
  }

  // ---- Pill surface + shadow ----
  Surface {
    id: pillSurface
    z: 1
    x: pill.x; y: pill.y; width: pill.width; height: pill.height
    role: "ground"
    material: Tokens.surfaceStyle
    topLeftRadius: pill.tlRadius
    topRightRadius: pill.trRadius
    bottomLeftRadius: pill.blRadius
    bottomRightRadius: pill.brRadius
    showBorder: !(win.isNotch && win.myMode === "idle")

    layer.enabled: Tokens.shadowsEnabled
    layer.effect: MultiEffect {
      shadowEnabled: Tokens.shadowsEnabled
      blurMax: 20
      shadowBlur: 0.72
      shadowColor: Qt.rgba(0, 0, 0, 1)
      shadowOpacity: win.myMode === "widget" ? 0.58 : 0.36
      shadowHorizontalOffset: 0
      shadowVerticalOffset: win.isBottom ? -4 : (win.myMode === "widget" ? 6 : 2)
    }
  }

  Item {
    id: pill
    z: 2
    x: Math.round((win.width - width) / 2)
    y: {
      if (win.isSpotlightMenu)
        return Math.round((win.height - height) * 0.28)
      var edgeOffset = (win.isNotch && win.myMode === "idle") ? 0 : win.topGap
      return win.isBottom ? Math.round(win.height - height - edgeOffset) : edgeOffset
    }
    Behavior on y {
      enabled: !Tokens.reducedMotion && !Tokens.gameMode
      SpringAnimation { spring: 5.2; damping: 0.58; epsilon: 0.25 }
    }

    width: win.target.width
    height: win.delayedH

    readonly property real baseRadius: win.myMode === "idle" ? Math.min(Tokens.radius.pill, height / 2) : Tokens.radius.lg
    property real tlRadius: (win.isNotch && win.myMode === "idle" && !win.isBottom) ? 0 : baseRadius
    property real trRadius: (win.isNotch && win.myMode === "idle" && !win.isBottom) ? 0 : baseRadius
    property real blRadius: (win.isNotch && win.myMode === "idle" && win.isBottom) ? 0 : baseRadius
    property real brRadius: (win.isNotch && win.myMode === "idle" && win.isBottom) ? 0 : baseRadius

    Behavior on width {
      enabled: !Tokens.reducedMotion && !Tokens.gameMode
      SpringAnimation { spring: win.shrinkW ? 6.0 : 3.4; damping: win.shrinkW ? 0.55 : 0.36; epsilon: 0.5 }
    }
    Behavior on height {
      enabled: !Tokens.reducedMotion && !Tokens.gameMode
      SpringAnimation { spring: win.shrinkH ? 6.0 : 3.0; damping: win.shrinkH ? 0.55 : 0.38; epsilon: 0.5 }
    }

    HoverHandler {
      onHoveredChanged: {
        IslandState.hoverIntent(hovered, win.screenName)
        if (hovered) Prefetch.touch()
      }
    }

    clip: true

    property string shownMode: "idle"
    property string shownWidget: ""
    property bool gating: false

    readonly property real rawFit: {
      function clamp(v) { return Math.max(0, Math.min(1, v)) }
      function fw(r) { return r < 1 ? clamp((r - 0.45) / 0.35) : clamp((3.2 - r) / 1.7) }
      function fh(r) { return r < 1 ? clamp((r - 0.10) / 0.45) : clamp((3.2 - r) / 1.7) }
      return Math.min(fw(width / Math.max(1, content.width)), fh(height / Math.max(1, content.height)))
    }
    readonly property real fit: gating ? rawFit : 1
    onRawFitChanged: if (gating && rawFit >= 0.98) gating = false
    Timer { interval: 500; running: pill.gating; onTriggered: pill.gating = false }

    Item {
      id: content
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: win.shownSize.width
      height: win.shownSize.height
      property real fade: 1
      opacity: fade * pill.fit
      focus: win.myMode === "widget"

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function (e) {
        IslandState.touch(true)
        var claimed = widgetLoader.item && widgetLoader.item.capturesEscape === true
        if (e.key === Qt.Key_Escape && !claimed) {
          IslandState.closeWidget("Esc")
          e.accepted = true
        }
      }

      SequentialAnimation {
        id: swap
        NumberAnimation {
          target: content; property: "fade"; to: 0
          duration: (Tokens.reducedMotion || Tokens.gameMode) ? 0 : 80
        }
        ScriptAction {
          script: {
            pill.shownMode = win.myMode
            pill.shownWidget = win.myMode === "widget" ? IslandState.widgetName : ""
            pill.gating = !(Tokens.reducedMotion || Tokens.gameMode)
          }
        }
        NumberAnimation {
          target: content; property: "fade"; to: 1
          duration: (Tokens.reducedMotion || Tokens.gameMode) ? 0 : 200
          easing.type: Easing.OutCubic
        }
      }

      Connections { target: win; function onMyModeChanged() { swap.restart() } }
      Connections {
        target: IslandState
        function onWidgetNameChanged() {
          if (win.myMode === "widget" && pill.shownWidget !== IslandState.widgetName) swap.restart()
        }
      }

      TopBar {
        id: topBar
        win: win
        anchors.fill: parent
        visible: pill.shownMode === "idle"
      }

      // ---- HUD ----
      Item {
        id: hudBox
        anchors.fill: parent
        visible: pill.shownMode === "hud"
        readonly property bool isText: IslandState.hudMessage !== ""
        readonly property string k: String(IslandState.hudKind || "").toLowerCase()
        property real shown: IslandState.hudValue
        Behavior on shown {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Slider {
          visible: !hudBox.isText
          anchors.fill: parent; anchors.margins: Tokens.space.sm
          style: "pill"
          from: 0; to: 100
          value: hudBox.shown
          icon: hudBox.k.indexOf("bright") === 0 || hudBox.k === "display" ? "brightness"
              : hudBox.k.indexOf("mic") === 0 ? (IslandState.hudValue <= 0 ? "mic-off" : "mic")
              : hudBox.k === "charger" ? "zap"
              : (IslandState.hudValue <= 0 ? "volume-mute" : "volume")
          showReadout: true
          unit: "%"
        }
        Row {
          visible: hudBox.isText
          anchors.centerIn: parent; spacing: Tokens.space.sm
          Icon {
            name: hudBox.k.indexOf("mic") === 0 ? "mic-off" : "info"
            size: Tokens.size.iconMd
            anchors.verticalCenter: parent.verticalCenter
          }
          TextLabel {
            text: IslandState.hudMessage
            role: "body"; font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ---- Notification toast ----
      Loader {
        id: toastLoader
        anchors.fill: parent
        active: pill.shownMode === "notification"
        sourceComponent: NotifToast { screenName: win.screenName }
      }

      // ---- Widget host ----
      Loader {
        id: widgetLoader
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: win.shownSize.width
        height: item ? item.implicitHeight : Registry.height(pill.shownWidget)
        active: pill.shownMode === "widget"
        focus: true
        source: active && pill.shownWidget !== "" ? "../Widgets/" + Registry.fileOf(pill.shownWidget) : ""
        onLoaded: {
          if (item.hasOwnProperty("reserve") && item.useReserve !== false)
            item.reserve = win.savedHeight(pill.shownWidget)
          sizeSave.restart()
          if (item.hasOwnProperty("initialFocus") && item.initialFocus) item.initialFocus.forceActiveFocus()
          else item.forceActiveFocus()
          if (item.hasOwnProperty("hostWindow")) item.hostWindow = win
        }
      }
    }
  }

  // ---- Detached ScrollRail (sibling in same PanelWindow) ----
  ScrollRail {
    id: rail
    z: 3
    target: (win.myMode === "widget" && widgetLoader.item && widgetLoader.item.scrollTarget) ? widgetLoader.item.scrollTarget : null
    anchorWidget: pill
    side: ConfigStore.scrollRailSide
    variant: ConfigStore.scrollRailVariant
    revealPolicy: "auto"
  }

  Timer {
    id: sizeSave
    interval: 700
    onTriggered: {
      var it = widgetLoader.item, name = pill.shownWidget
      if (!it || name === "" || it.dataLoading === true || !(it.implicitHeight > 0)) return
      var m = Object.assign({}, Cache.get("wsize") || {})
      if (Math.abs((m[name] || 0) - it.implicitHeight) < 2) return
      m[name] = Math.round(it.implicitHeight)
      Cache.put("wsize", m)
    }
  }
  Connections {
    target: widgetLoader.item
    ignoreUnknownSignals: true
    function onImplicitHeightChanged() { sizeSave.restart() }
  }

  property real delayedH: target.height
  property size prevTarget: Qt.size(0, 0)
  property bool shrinkW: false
  property bool shrinkH: false
  onTargetChanged: {
    shrinkW = target.width < prevTarget.width
    shrinkH = target.height < prevTarget.height
    prevTarget = target
    if (Tokens.reducedMotion || Tokens.gameMode) delayedH = target.height
    else heightGate.restart()
  }
  Timer { id: heightGate; interval: 40; onTriggered: win.delayedH = win.target.height }
}
