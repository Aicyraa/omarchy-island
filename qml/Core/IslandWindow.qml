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

// IslandWindow: one per screen. Full-screen transparent PanelWindow masked to exact
// pill + detached ScrollRail Regions so everything else passes clicks straight through.
PanelWindow {
  id: win

  required property var modelData
  property bool rig: false

  screen: modelData
  readonly property string screenName: modelData.name

  readonly property string globalMode: IslandState.mode
  readonly property string myMode:
    globalMode === "idle" ? "idle" : (screenName === IslandState.activeScreen ? globalMode : "idle")
  readonly property string myWidget: myMode === "widget" ? IslandState.widgetName : ""

  readonly property bool isTop: ConfigStore.barPosition === "top"
  readonly property bool isBottom: ConfigStore.barPosition === "bottom"
  readonly property bool isLeft: ConfigStore.barPosition === "left"
  readonly property bool isRight: ConfigStore.barPosition === "right"
  readonly property bool isVertical: isLeft || isRight

  readonly property bool isNotch: ConfigStore.barStyle === "notch"
  readonly property bool isFullBar: ConfigStore.barStyle === "full"
  readonly property bool isSpotlightMenu: myMode === "widget" && myWidget === "menu" && ConfigStore.menuPresentation === "spotlight"

  readonly property bool detachedMode: !isNotch || isSpotlightMenu
  readonly property int topGap: 6
  readonly property int notchMargin: 10
  readonly property int barHeight: 36
  readonly property int vBarWidth: 48
  readonly property int ear: 12

  function dur(ms) {
    return (Tokens.reducedMotion || Tokens.gameMode) ? 0 : Math.round(ms * Tokens.motionScale)
  }

  function savedWidth(name) {
    var m = Cache.get("wsize")
    var e = m ? m[name] : null
    return (e && typeof e === "object" && e.w > 0) ? e.w : 0
  }

  function savedHeight(name) {
    var m = Cache.get("wsize")
    var e = m ? m[name] : null
    if (typeof e === "number") return e
    return (e && typeof e === "object" && e.h > 0) ? e.h : 0
  }

  function widgetSizeOf(name) {
    var it = widgetLoader.item
    if (it && pill.shownWidget === name && it.implicitHeight > 0)
      return Qt.size(Math.min(Tokens.px(940), it.implicitWidth), it.implicitHeight)
    var savedW = (name === "wifi") ? 0 : savedWidth(name)
    var savedH = (name === "wifi") ? 0 : savedHeight(name)
    return Qt.size(savedW > 0 ? savedW : Registry.width(name), savedH > 0 ? savedH : Registry.height(name))
  }

  function sizeFor(m, wName) {
    switch (m) {
    case "widget":       return widgetSizeOf(wName !== undefined ? wName : IslandState.widgetName)
    case "hud":          return Qt.size(300, 44)
    case "notification": return Qt.size(420, 68)
    default:
      if (win.isVertical) {
        var vh = isFullBar && win.screen ? Math.max(240, win.screen.height - 2 * Tokens.compositorGapsOut) : topBar.heightFor()
        return Qt.size(win.vBarWidth, vh)
      }
      var hw = isFullBar && win.screen ? Math.max(320, win.screen.width - 2 * Tokens.compositorGapsOut) : topBar.widthFor()
      return Qt.size(hw, win.barHeight)
    }
  }

  function isSpotlightFor(mode, wName) {
    return mode === "widget" && wName === "menu" && ConfigStore.menuPresentation === "spotlight"
  }

  function isNotchAttached(mode, wName) {
    return win.isNotch && !isSpotlightFor(mode, wName)
  }

  function calcY(mode, wName, h) {
    if (isSpotlightFor(mode, wName))
      return Math.round((win.height - h) * 0.28)
    if (win.isVertical)
      return Math.round((win.height - h) / 2)
    var edgeOffset = isNotchAttached(mode, wName) ? 0 : win.topGap
    return win.isBottom ? Math.round(win.height - h - edgeOffset) : edgeOffset
  }

  function calcBaseRadius(mode, w, h) {
    return mode === "idle" ? Math.min(Tokens.radius.pill, Math.min(w, h) / 2) : Tokens.radius.lg
  }
  function calcTlR(mode, wName, w, h) { return (isNotchAttached(mode, wName) && (win.isTop || win.isLeft)) ? 0 : calcBaseRadius(mode, w, h) }
  function calcTrR(mode, wName, w, h) { return (isNotchAttached(mode, wName) && (win.isTop || win.isRight)) ? 0 : calcBaseRadius(mode, w, h) }
  function calcBlR(mode, wName, w, h) { return (isNotchAttached(mode, wName) && (win.isBottom || win.isLeft)) ? 0 : calcBaseRadius(mode, w, h) }
  function calcBrR(mode, wName, w, h) { return (isNotchAttached(mode, wName) && (win.isBottom || win.isRight)) ? 0 : calcBaseRadius(mode, w, h) }

  readonly property size target: sizeFor(myMode, myWidget)
  readonly property size shownSize: pill.shownMode === "widget" ? widgetSizeOf(pill.shownWidget) : sizeFor(pill.shownMode, pill.shownWidget)
  readonly property size idleSize: sizeFor("idle", "")

  function pillBox() {
    return Qt.size(target.width + 2 * ear, target.height + topGap)
  }

  Component.onCompleted: {
    pill.applyImmediate(win.myMode, win.myWidget)
    IslandState.islands[screenName] = win
    IslandState.setZone(screenName, zoneRect)
  }
  Component.onDestruction: delete IslandState.islands[screenName]

  color: "transparent"
  anchors.top: !win.isBottom
  anchors.bottom: !win.isTop
  anchors.left: !win.isRight
  anchors.right: !win.isLeft
  implicitWidth: win.screen ? win.screen.width : 1920
  implicitHeight: win.screen ? win.screen.height : 1080
  exclusionMode: rig ? ExclusionMode.Ignore : ExclusionMode.Normal

  readonly property int barThickness: win.isVertical ? win.vBarWidth : win.barHeight
  readonly property int barMarginTotal: win.isNotch ? win.notchMargin : (2 * win.topGap)
  exclusiveZone: win.rig ? 0 : Math.max(0, win.barThickness + win.barMarginTotal - Tokens.compositorGapsOut)

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

  // ---- Input region: pill + detached ScrollRail ----
  readonly property real pillHitX: Math.round(pill.x - (!win.isVertical && !win.detachedMode ? win.ear : 0))
  readonly property real pillHitY: Math.round(pill.y - (win.isVertical && !win.detachedMode ? win.ear : 0))
  readonly property real pillHitW: Math.round(pill.width + (!win.isVertical && !win.detachedMode ? 2 * win.ear : 0))
  readonly property real pillHitH: Math.round(pill.height + (win.isVertical && !win.detachedMode ? 2 * win.ear : 0))

  readonly property real zoneMinX: Math.min(pillHitX, rail.needed ? rail.inputRect.x : pillHitX)
  readonly property real zoneMinY: Math.min(pillHitY, rail.needed ? rail.inputRect.y : pillHitY)
  readonly property real zoneMaxX: Math.max(pillHitX + pillHitW, rail.needed ? rail.inputRect.x + rail.inputRect.width : pillHitX + pillHitW)
  readonly property real zoneMaxY: Math.max(pillHitY + pillHitH, rail.needed ? rail.inputRect.y + rail.inputRect.height : pillHitY + pillHitH)
  readonly property rect zoneRect: Qt.rect(Math.round(zoneMinX), Math.round(zoneMinY), Math.round(zoneMaxX - zoneMinX), Math.round(zoneMaxY - zoneMinY))
  onZoneRectChanged: IslandState.setZone(screenName, zoneRect)

  mask: Region {
    Region {
      x: win.pillHitX
      y: win.pillHitY
      width: win.pillHitW
      height: win.pillHitH
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
      position: ConfigStore.barPosition,
      style: ConfigStore.barStyle,
      pill: { w: Math.round(pill.width), h: Math.round(pill.height), tw: Math.round(win.target.width), th: Math.round(win.target.height) },
      content: ink.length ? { l: Math.round(L), t: Math.round(T), r: Math.round(R), b: Math.round(B) } : null,
      pad: ink.length ? { top: Math.round(T), left: Math.round(L), right: Math.round(pill.width - R), bottom: Math.round(pill.height - B) } : null,
      overflowX: over.length,
      railNeeded: rail.needed,
      reveal: { shown: pill.shownMode, fade: +content.contentOpacity.toFixed(2), morphing: pill.transitioning, opacity: +content.opacity.toFixed(2) },
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

  // ---- Concave notch ears (horizontal: top/bottom, vertical: left/right) ----
  Shape {
    z: 3
    opacity: !win.isVertical && !win.detachedMode ? 1 : 0
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
    opacity: !win.isVertical && !win.detachedMode ? 1 : 0
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

  Shape {
    z: 3
    opacity: win.isVertical && !win.detachedMode ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { enabled: !Tokens.reducedMotion && !Tokens.gameMode; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    x: win.isRight ? pill.x + pill.width - win.ear : pill.x
    y: pill.y - win.ear
    width: win.ear; height: win.ear
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Tokens.groundOf(Tokens.surfaceStyle); strokeWidth: 0; strokeColor: "transparent"
      startX: win.isRight ? win.ear : 0; startY: 0
      PathQuad { x: win.isRight ? 0 : win.ear; y: win.ear; controlX: win.isRight ? win.ear : 0; controlY: win.ear }
      PathLine { x: win.isRight ? win.ear : 0; y: win.ear }
      PathLine { x: win.isRight ? win.ear : 0; y: 0 }
    }
  }

  Shape {
    z: 3
    opacity: win.isVertical && !win.detachedMode ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { enabled: !Tokens.reducedMotion && !Tokens.gameMode; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    x: win.isRight ? pill.x + pill.width - win.ear : pill.x
    y: pill.y + pill.height
    width: win.ear; height: win.ear
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Tokens.groundOf(Tokens.surfaceStyle); strokeWidth: 0; strokeColor: "transparent"
      startX: win.isRight ? win.ear : 0; startY: win.ear
      PathQuad { x: win.isRight ? 0 : win.ear; y: 0; controlX: win.isRight ? win.ear : 0; controlY: 0 }
      PathLine { x: win.isRight ? win.ear : 0; y: 0 }
      PathLine { x: win.isRight ? win.ear : 0; y: win.ear }
    }
  }

  // ---- Smooth SDF Drop Shadow (zero FBO allocation during morph) ----
  RectangularShadow {
    id: pillShadow
    z: 0
    visible: Tokens.elevation.shadowsActive && win.detachedMode
    anchors.fill: pillSurface
    cached: false
    offset: Qt.vector2d(
      win.isLeft ? 2 : (win.isRight ? -2 : 0),
      win.isVertical ? 2 : (win.isBottom ? -3 : 4)
    )
    blur: pill.shownMode === "idle" ? 18 : 28
    spread: 0
    color: Qt.rgba(0, 0, 0, pill.shownMode === "idle" ? 0.36 : 0.48)
    topLeftRadius: pill.animTlR
    topRightRadius: pill.animTrR
    bottomLeftRadius: pill.animBlR
    bottomRightRadius: pill.animBrR
  }

  // ---- Pill surface ----
  Surface {
    id: pillSurface
    z: 1
    x: pill.x; y: pill.y; width: pill.width; height: pill.height
    role: "ground"
    material: Tokens.surfaceStyle
    topLeftRadius: pill.animTlR
    topRightRadius: pill.animTrR
    bottomLeftRadius: pill.animBlR
    bottomRightRadius: pill.animBrR
    showBorder: win.detachedMode
  }

  Item {
    id: pill
    z: 2

    property string shownMode: "idle"
    property string shownWidget: ""
    property string pendingMode: "idle"
    property string pendingWidget: ""
    property int retargetCount: 0
    readonly property bool transitioning: hideAnim.running || reshapeKick.running || reshapeAnim.running || revealTrigger.running || revealAnim.running

    // Live user-configurable cubic-bezier curves driven by ConfigStore.motionCurve
    function activeCurve4() {
      var c = ConfigStore.motionCurve
      if (c && c.length === 4) return [Number(c[0]), Number(c[1]), Number(c[2]), Number(c[3])]
      return [0.05, 0.92, 0.12, 1.04]
    }

    function dampedCurve(c, posScale, negScale, maxOvershoot, minUndershoot) {
      var y1 = c[1] > 1.0 ? Math.min(maxOvershoot, 1.0 + (c[1] - 1.0) * posScale)
                          : (c[1] < 0.0 ? Math.max(minUndershoot, c[1] * negScale) : c[1])
      var y2 = c[3] > 1.0 ? Math.min(maxOvershoot, 1.0 + (c[3] - 1.0) * posScale)
                          : (c[3] < 0.0 ? Math.max(minUndershoot, c[3] * negScale) : c[3])
      return [c[0], y1, c[2], y2, 1.0, 1.0]
    }

    function revealRatioFor(c) {
      for (var u = 0.05; u <= 1.0001; u += 0.025) {
        var omt = 1.0 - u
        var x = 3 * omt * omt * u * c[0] + 3 * omt * u * u * c[2] + u * u * u
        var y = 3 * omt * omt * u * c[1] + 3 * omt * u * u * c[3] + u * u * u
        if (y >= 0.96)
          return Math.max(0.30, Math.min(0.70, x))
      }
      return 0.48
    }

    readonly property var curveGrow: {
      var c = pill.activeCurve4()
      return [c[0], c[1], c[2], c[3], 1.0, 1.0]
    }
    readonly property var curveShrinkW:  pill.dampedCurve(pill.activeCurve4(), 0.45, 0.50, 1.25, -0.15)
    readonly property var curveShrinkH:  pill.dampedCurve(pill.activeCurve4(), 0.15, 0.30, 1.03, -0.08)
    readonly property var curveOutExpo:  [0.16, 1.0, 0.30, 1.0, 1.0, 1.0]
    readonly property var curveRevealPop: [0.12, 1.04, 0.24, 1.0, 1.0, 1.0]

    property real animW: 220
    property real animH: 36
    property real animY: 6
    property real animTlR: 18
    property real animTrR: 18
    property real animBlR: 18
    property real animBrR: 18

    property real destW: 220
    property real destH: 36
    property real destY: 6
    property real destTlR: 18
    property real destTrR: 18
    property real destBlR: 18
    property real destBrR: 18

    width: animW
    height: animH
    y: animY
    x: {
      if (win.isSpotlightMenu || !win.isVertical) return Math.round((win.width - width) / 2)
      var edgeOffset = win.isNotch ? 0 : win.topGap
      if (win.isLeft) return edgeOffset
      return Math.round(win.width - width - edgeOffset)
    }

    function computeDest(mode, wName) {
      var sz = win.sizeFor(mode, wName)
      destW = sz.width
      destH = sz.height
      destY = win.calcY(mode, wName, destH)
      destTlR = win.calcTlR(mode, wName, destW, destH)
      destTrR = win.calcTrR(mode, wName, destW, destH)
      destBlR = win.calcBlR(mode, wName, destW, destH)
      destBrR = win.calcBrR(mode, wName, destW, destH)
    }

    function applyImmediate(mode, wName) {
      shownMode = mode
      shownWidget = wName
      computeDest(mode, wName)
      animW = destW
      animH = destH
      animY = destY
      animTlR = destTlR
      animTrR = destTrR
      animBlR = destBlR
      animBrR = destBrR
      content.contentOpacity = 1
      content.contentScale = 1
      content.contentSlideY = 0
    }

    function stopAllTransitions() {
      liveResizeAnim.stop()
      hideAnim.stop()
      reshapeKick.stop()
      reshapeAnim.stop()
      revealTrigger.stop()
      revealAnim.stop()
    }

    function startTransition(nextMode, nextWidget) {
      stopAllTransitions()
      retargetCount = 0
      pendingMode = nextMode
      pendingWidget = nextWidget
      if (win.dur(1) === 0) {
        applyImmediate(nextMode, nextWidget)
        return
      }
      if (content.contentOpacity <= 0.05) {
        beginSwapAndMeasure()
      } else {
        hideAnim.start()
      }
    }

    function beginSwapAndMeasure() {
      content.contentOpacity = 0
      shownMode = pendingMode
      shownWidget = pendingWidget
      content.contentScale = 0.93
      content.contentSlideY = (pendingMode === "idle") ? (win.isBottom ? 4 : -4) : (win.isBottom ? 10 : -10)
      // Give Loader 1 event-loop tick to complete QML instantiation & layout before starting the reshape clock
      reshapeKick.restart()
    }

    function startReshape() {
      computeDest(shownMode, shownWidget)
      var growingW = destW >= animW
      var growingH = destH >= animH
      var wDur = win.dur(growingW ? 420 : 340)
      var hDelay = win.dur(10)
      var hDur = win.dur(growingH ? 420 : 340)
      var yDur = win.dur(growingH ? 400 : 340)
      var rDur = win.dur(320)
      morphWAnim.to = destW
      morphWAnim.duration = wDur
      morphWAnim.easing.bezierCurve = growingW ? pill.curveGrow : pill.curveShrinkW
      morphHDelay.duration = hDelay
      morphHAnim.to = destH
      morphHAnim.duration = hDur
      morphHAnim.easing.bezierCurve = growingH ? pill.curveGrow : pill.curveShrinkH
      morphYAnim.to = destY
      morphYAnim.duration = yDur
      morphYAnim.easing.bezierCurve = growingH ? pill.curveGrow : pill.curveShrinkW
      morphTlAnim.to = destTlR; morphTlAnim.duration = rDur
      morphTrAnim.to = destTrR; morphTrAnim.duration = rDur
      morphBlAnim.to = destBlR; morphBlAnim.duration = rDur
      morphBrAnim.to = destBrR; morphBrAnim.duration = rDur
      reshapeAnim.start()
      var totalReshape = Math.max(wDur, hDelay + hDur)
      revealTrigger.interval = Math.max(1, Math.round(totalReshape * pill.revealRatioFor(pill.activeCurve4())))
      revealTrigger.restart()
    }

    function handleSizeUpdate() {
      if (reshapeKick.running)
        return
      if (reshapeAnim.running && content.contentOpacity < 0.05 && retargetCount < 2) {
        var prevW = destW, prevH = destH, prevY = destY
        computeDest(shownMode, shownWidget)
        if (Math.abs(destW - prevW) >= 2 || Math.abs(destH - prevH) >= 2 || Math.abs(destY - prevY) >= 2) {
          retargetCount++
          startReshape()
        }
        return
      }
      syncLiveSize()
    }

    function syncLiveSize() {
      if (transitioning) return
      computeDest(shownMode, shownWidget)
      if (Math.abs(animW - destW) < 1.5 && Math.abs(animH - destH) < 1.5 && Math.abs(animY - destY) < 1.5)
        return
      if (win.dur(1) === 0) {
        animW = destW; animH = destH; animY = destY
        animTlR = destTlR; animTrR = destTrR; animBlR = destBlR; animBrR = destBrR
        return
      }
      var growingW = destW >= animW
      var growingH = destH >= animH
      liveWAnim.to = destW; liveWAnim.duration = win.dur(280); liveWAnim.easing.bezierCurve = growingW ? pill.curveGrow : pill.curveShrinkW
      liveHAnim.to = destH; liveHAnim.duration = win.dur(280); liveHAnim.easing.bezierCurve = growingH ? pill.curveGrow : pill.curveShrinkH
      liveYAnim.to = destY; liveYAnim.duration = win.dur(260)
      liveTlAnim.to = destTlR; liveTlAnim.duration = win.dur(240)
      liveTrAnim.to = destTrR; liveTrAnim.duration = win.dur(240)
      liveBlAnim.to = destBlR; liveBlAnim.duration = win.dur(240)
      liveBrAnim.to = destBrR; liveBrAnim.duration = win.dur(240)
      liveResizeAnim.restart()
    }

    HoverHandler {
      onHoveredChanged: {
        IslandState.hoverIntent(hovered, win.screenName)
        if (hovered) Prefetch.touch()
      }
    }

    clip: true

    Timer {
      id: reshapeKick
      interval: 16
      repeat: false
      onTriggered: pill.startReshape()
    }

    Timer {
      id: revealTrigger
      interval: 1
      repeat: false
      onTriggered: revealAnim.start()
    }

    // Phase 1: Hide current content cleanly
    ParallelAnimation {
      id: hideAnim
      NumberAnimation { target: content; property: "contentOpacity"; to: 0; duration: win.dur(55); easing.type: Easing.InQuart }
      NumberAnimation { target: content; property: "contentScale"; to: 0.94; duration: win.dur(55); easing.type: Easing.InQuart }
      NumberAnimation { target: content; property: "contentSlideY"; to: win.isBottom ? 5 : -5; duration: win.dur(55); easing.type: Easing.InQuart }
      onFinished: pill.beginSwapAndMeasure()
    }

    // Phase 2: Spring-spline Dynamic-Island reshape (content stays hidden until overshoot crest)
    ParallelAnimation {
      id: reshapeAnim
      NumberAnimation { id: morphWAnim; target: pill; property: "animW"; to: pill.destW; duration: win.dur(380); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveGrow }
      SequentialAnimation {
        PauseAnimation { id: morphHDelay; duration: win.dur(24) }
        NumberAnimation { id: morphHAnim; target: pill; property: "animH"; to: pill.destH; duration: win.dur(390); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveGrow }
      }
      NumberAnimation { id: morphYAnim; target: pill; property: "animY"; to: pill.destY; duration: win.dur(375); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveGrow }
      NumberAnimation { id: morphTlAnim; target: pill; property: "animTlR"; to: pill.destTlR; duration: win.dur(310); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { id: morphTrAnim; target: pill; property: "animTrR"; to: pill.destTrR; duration: win.dur(310); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { id: morphBlAnim; target: pill; property: "animBlR"; to: pill.destBlR; duration: win.dur(310); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { id: morphBrAnim; target: pill; property: "animBrR"; to: pill.destBrR; duration: win.dur(310); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      onFinished: {
        if (!revealAnim.running && !revealTrigger.running && content.contentOpacity < 0.99)
          revealAnim.start()
        else if (!pill.transitioning)
          pill.syncLiveSize()
      }
    }

    // Phase 3: Pop-in new content seamlessly into the settling cushion
    ParallelAnimation {
      id: revealAnim
      NumberAnimation { target: content; property: "contentOpacity"; to: 1; duration: win.dur(200); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { target: content; property: "contentScale"; to: 1.0; duration: win.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveRevealPop }
      NumberAnimation { target: content; property: "contentSlideY"; to: 0; duration: win.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveRevealPop }
      onFinished: if (!pill.transitioning) pill.syncLiveSize()
    }

    ParallelAnimation {
      id: liveResizeAnim
      NumberAnimation { id: liveWAnim; target: pill; property: "animW"; to: pill.destW; duration: win.dur(280); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveGrow }
      NumberAnimation { id: liveHAnim; target: pill; property: "animH"; to: pill.destH; duration: win.dur(280); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveGrow }
      NumberAnimation { id: liveYAnim; target: pill; property: "animY"; to: pill.destY; duration: win.dur(260); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { id: liveTlAnim; target: pill; property: "animTlR"; to: pill.destTlR; duration: win.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { id: liveTrAnim; target: pill; property: "animTrR"; to: pill.destTrR; duration: win.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { id: liveBlAnim; target: pill; property: "animBlR"; to: pill.destBlR; duration: win.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
      NumberAnimation { id: liveBrAnim; target: pill; property: "animBrR"; to: pill.destBrR; duration: win.dur(240); easing.type: Easing.BezierSpline; easing.bezierCurve: pill.curveOutExpo }
    }

    Connections {
      target: win
      function onMyModeChanged() { pill.startTransition(win.myMode, win.myWidget) }
      function onMyWidgetChanged() {
        if (win.myMode === "widget" && pill.pendingWidget !== win.myWidget)
          pill.startTransition(win.myMode, win.myWidget)
      }
      function onTargetChanged() { pill.handleSizeUpdate() }
    }

    Item {
      id: content
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: win.shownSize.width
      height: win.shownSize.height

      property real contentOpacity: 1
      property real contentScale: 1
      property real contentSlideY: 0

      // Keep visible: true so Qt Quick layouts run full polish before startReshape() measures
      visible: true
      enabled: contentOpacity > 0.5
      opacity: contentOpacity
      scale: contentScale
      transformOrigin: Item.Top
      transform: Translate { y: content.contentSlideY }
      focus: win.myMode === "widget"

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function (e) {
        IslandState.touch(true)
        if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab || e.key === Qt.Key_Up || e.key === Qt.Key_Down || e.key === Qt.Key_Left || e.key === Qt.Key_Right)
          Tokens.keyboardNavigation = true
        var claimed = widgetLoader.item && widgetLoader.item.capturesEscape === true
        if (e.key === Qt.Key_Escape && !claimed) {
          IslandState.closeWidget("Esc")
          e.accepted = true
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
          NumberAnimation { duration: win.dur(120); easing.type: Easing.OutCubic }
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
          pill.handleSizeUpdate()
        }
      }
    }
  }

  // ---- Detached ScrollRail (sibling in same PanelWindow; hidden during morph) ----
  ScrollRail {
    id: rail
    z: 3
    target: (win.myMode === "widget" && !pill.transitioning && widgetLoader.item)
      ? (widgetLoader.item.effectiveScrollTarget || widgetLoader.item.scrollTarget || null)
      : null
    anchorWidget: pill
    side: win.isRight ? "left" : (win.isLeft ? "right" : ConfigStore.scrollRailSide)
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
      var nw = Math.round(it.implicitWidth), nh = Math.round(it.implicitHeight)
      var prev = m[name]
      if (prev && typeof prev === "object" && Math.abs((prev.w || 0) - nw) < 2 && Math.abs((prev.h || 0) - nh) < 2)
        return
      m[name] = { w: nw, h: nh }
      Cache.put("wsize", m)
    }
  }
  Connections {
    target: widgetLoader.item
    ignoreUnknownSignals: true
    function onImplicitHeightChanged() { sizeSave.restart(); pill.handleSizeUpdate() }
    function onImplicitWidthChanged() { sizeSave.restart(); pill.handleSizeUpdate() }
  }
}
