import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "."
import "services"
import "widgets/Registry.js" as Registry

// One Island per screen (created by Variants in Bar.qml).
//
// IMPORTANT DESIGN RULE: the PanelWindow is a FIXED size (big enough for the
// largest possible panel) and transparent. We never animate the window's size:
// every size change makes the compositor re-configure the layer surface, which
// stutters. Only the inner `pill` Rectangle animates, and `mask` tells the
// compositor that clicks outside the pill fall through to the apps underneath.
PanelWindow {
  id: win

  required property var modelData      // injected by Variants: a ShellScreen
  property bool rig: false             // test rig: don't reserve screen space

  screen: modelData
  readonly property string screenName: modelData.name
  // What THIS screen shows right now (idle on every screen unless it owns the
  // widget/HUD/hover).
  readonly property string myMode: IslandState.modeFor(screenName)

  // ---- geometry: pill size per mode ----
  readonly property int topMargin: 0      // flush with the top edge
  readonly property int ear: 12           // concave corner ears (same as the Compass menu)

  // CONTENT-SIZED PANELS: a widget's pill size is its own implicit size
  // (content + padding, clamped). Until the widget is loaded (the first ~100 ms
  // of an open, or while A is fading into B) we use the Registry's estimate; when
  // the real item appears the spring simply retargets, with no restart of the fade.
  function widgetSize() {
    var name = IslandState.widgetName
    var it = widgetLoader.item
    if (it && pill.shownWidget === name && it.implicitHeight > 0)
      return Qt.size(Math.min(Theme.panelMaxWidth, it.implicitWidth), it.implicitHeight)
    return Qt.size(Registry.width(name), Registry.height(name))
  }
  function sizeFor(m) {
    switch (m) {
    case "hover":        return Qt.size(idleForm.widthFor(true), 38)
    case "widget":       return widgetSize()
    case "hud":          return Qt.size(300, 42)
    case "notification": return Qt.size(420, 52)
    default:             return Qt.size(idleForm.widthFor(false), 26)     // idle
    }
  }
  readonly property size target: sizeFor(myMode)
  readonly property size idleSize: sizeFor("idle")

  color: "transparent"
  anchors.top: true                     // top edge only -> centered horizontally
  implicitWidth: Theme.panelMaxWidth + 2 * ear + 16
  implicitHeight: Theme.panelMaxHeight + 20
  // Reserve exactly the collapsed height so tiled windows don't jump when the
  // pill grows (it overlays windows instead).
  exclusionMode: rig ? ExclusionMode.Ignore : ExclusionMode.Normal
  exclusiveZone: topMargin + idleSize.height

  WlrLayershell.namespace: "aicyraa-island"
  // Only grab the keyboard while a widget is open on this screen.
  WlrLayershell.keyboardFocus: myMode === "widget" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // Hide in fullscreen unless the user explicitly opened a widget.
  visible: !IslandState.barHidden && !(IslandState.fullscreen && myMode !== "widget")

  // Click-outside closes a widget: while open, a focus grab watches for a click
  // elsewhere and reports `cleared`.
  HyprlandFocusGrab {
    windows: [win]
    active: win.myMode === "widget"
    onCleared: IslandState.closeWidget()
  }

  // ---- input region ----
  // `zone` is the hover target and the clickable area. For idle/hover it is a few
  // px bigger than the pill's TARGET size, which "bridges" the gap while the pill
  // is mid-spring so moving into the expanded pill never counts as leaving. For a
  // widget it is EXACTLY the pill (plus the ears), so clicks just outside pass through.
  mask: Region { item: zone }
  Item {
    id: zone
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: win.target.width + 2 * win.ear
    height: win.topMargin + win.target.height + (win.myMode === "widget" ? 0 : 6)
    HoverHandler { onHoveredChanged: IslandState.hoverIntent(hovered, win.screenName) }
  }

  // ---- debug: measure + overlay (inactive unless `island debug ...` is used) ----
  // walk(): collects every visible descendant's box in PILL coordinates. Text
  // reports its PAINTED box (contentWidth/Height), Shapes their scaled box.
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
      } else if (c.preferredRendererType !== undefined) { kind = "shape"; w = c.width * c.scale; h = c.height * c.scale }
      else if (c.radius !== undefined && c.children.length === 0 && c.width <= 40 && c.height <= 40) kind = "shape"   // dots, bars, fills
      else if (c.paintedWidth !== undefined) { kind = "image"; w = c.paintedWidth; h = c.paintedHeight }
      out.push({ x: x, y: p.y, w: w, h: h, kind: kind, name: c.objectName || "" })
      if (depth < 9) walk(c, out, depth + 1)
    }
  }
  property var debugRects: []
  function refreshDebug() { var out = []; walk(content, out, 0); debugRects = out }
  function measure() {
    var all = []; walk(content, all, 0)
    var ink = all.filter(function (r) { return r.kind === "text" || r.kind === "shape" || r.kind === "image" })
    var L = 1e9, T = 1e9, R = -1e9, B = -1e9, over = []
    ink.forEach(function (r) {
      // Ignore things scrolled out of view inside a panel (they are clipped, not overflowing).
      if (r.y >= pill.height || r.y + r.h <= 0) return
      L = Math.min(L, r.x); T = Math.min(T, r.y); R = Math.max(R, r.x + r.w); B = Math.max(B, r.y + r.h)
      if (r.x < -0.5 || r.x + r.w > pill.width + 0.5) over.push(r)
    })
    // Block-level padding: the panel's own content blocks (rows, cards, tiles), which is
    // what "padding" means visually. Ink padding above includes padding INSIDE cards.
    var blocks = null, scrolls = false
    var it = widgetLoader.item
    if (win.myMode === "widget" && it && it.column !== undefined) {
      var bt = 1e9, bb = -1e9, bl = 1e9, br = -1e9
      var kids = it.column.children
      for (var i = 0; i < kids.length; i++) {
        var k = kids[i]; if (!k.visible || k.height <= 0 || k.width <= 0) continue
        var p = k.mapToItem(pill, 0, 0)
        bt = Math.min(bt, p.y); bb = Math.max(bb, p.y + k.height); bl = Math.min(bl, p.x); br = Math.max(br, p.x + k.width)
      }
      scrolls = it.scrollable === true
      var footer = it.footerH || 0
      blocks = { top: Math.round(bt), bottom: scrolls ? null : Math.round(pill.height - footer - bb),
                 left: Math.round(bl), right: Math.round(pill.width - br), footer: footer, scrolls: scrolls }
    }
    var clock = all.filter(function (r) { return r.name === "clockText" })[0]
    return JSON.stringify({
      mode: myMode, widget: IslandState.widgetName,
      pill: { w: Math.round(pill.width), h: Math.round(pill.height), tw: win.target.width, th: win.target.height },
      content: ink.length ? { l: Math.round(L), t: Math.round(T), r: Math.round(R), b: Math.round(B) } : null,
      pad: ink.length ? { top: Math.round(T), left: Math.round(L), right: Math.round(pill.width - R), bottom: Math.round(pill.height - B) } : null,
      blocks: blocks,
      overflowX: over.length,
      zone: { w: Math.round(zone.width), h: Math.round(zone.height) },
      clockDX: clock ? +((clock.x + clock.w / 2) - pill.width / 2).toFixed(1) : null,
      items: all.length })
  }
  Connections { target: IslandState
    function onMeasureRequested() { if (win.myMode !== "idle" || win.screenName === IslandState.focusedScreenName()) IslandState.measureResult = win.measure() } }
  Timer { interval: 400; repeat: true; running: IslandState.debugLayout; triggeredOnStart: true; onTriggered: win.refreshDebug() }

  // Concave "ears": small inverted corners on each side that flare the pill into
  // the screen edge, exactly like the Compass menu. Each is a filled quarter-
  // curve drawn with a Shape; they sit beside the pill (not inside it, because
  // the pill clips its content).
  Shape {
    x: pill.x - win.ear; y: win.topMargin
    width: win.ear; height: win.ear
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Theme.pill; strokeWidth: 0; strokeColor: "transparent"
      startX: 0; startY: 0
      PathQuad { x: win.ear; y: win.ear; controlX: win.ear; controlY: 0 }
      PathLine { x: win.ear; y: 0 }
      PathLine { x: 0; y: 0 }
    }
  }
  Shape {
    x: pill.x + pill.width; y: win.topMargin
    width: win.ear; height: win.ear
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: Theme.pill; strokeWidth: 0; strokeColor: "transparent"
      startX: win.ear; startY: 0
      PathQuad { x: 0; y: win.ear; controlX: 0; controlY: 0 }
      PathLine { x: 0; y: 0 }
      PathLine { x: win.ear; y: 0 }
    }
  }

  Rectangle {
    id: pill
    y: win.topMargin
    anchors.horizontalCenter: parent.horizontalCenter
    width: win.target.width
    height: win.delayedH
    // Attached to the top edge: square top corners, rounded bottom corners
    // (per-corner radii need Qt 6.7+).
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: Math.min(Theme.pillRadius, height / 2)
    bottomRightRadius: Math.min(Theme.pillRadius, height / 2)
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

    // Debug overlay: every item's box (magenta = text, cyan = icon/shape, yellow = other),
    // the pill bounds (red) and the shared inset guide (green).
    Item {
      z: 100; visible: IslandState.debugLayout; anchors.fill: parent
      Repeater { model: IslandState.debugLayout ? win.debugRects : []
        delegate: Rectangle { required property var modelData
          x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; color: "transparent"; border.width: 1
          border.color: modelData.kind === "text" ? Qt.rgba(1, 0, 1, 0.8) : modelData.kind === "shape" ? Qt.rgba(0, 1, 1, 0.8) : Qt.rgba(1, 1, 0, 0.35) } }
      Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 0, 0, 0.9) }
      Rectangle { x: Theme.panelPadding; y: Theme.panelPadding; width: parent.width - 2 * Theme.panelPadding; height: parent.height - 2 * Theme.panelPadding
        color: "transparent"; border.width: 1; border.color: Qt.rgba(0, 1, 0, 0.6) }
    }

    // ---- content, crossfaded in two beats ----
    // The content item has the TARGET size and is pinned to the top-center, so
    // it never visibly squishes while the pill springs around it.
    property string shownMode: "idle"
    property string shownWidget: ""        // the widget currently loaded (lags widgetName by the fade-out)
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
      // opacity, so rapid changes never leave stale content. Runs on a mode
      // change AND when one widget is swapped for another (A -> B).
      SequentialAnimation {
        id: swap
        NumberAnimation { target: content; property: "opacity"; to: 0
          duration: IslandState.reducedMotion ? 0 : 80 }
        ScriptAction { script: { pill.shownMode = win.myMode; pill.shownWidget = win.myMode === "widget" ? IslandState.widgetName : "" } }
        NumberAnimation { target: content; property: "opacity"; to: 1
          duration: IslandState.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic }
      }
      Connections { target: win; function onMyModeChanged() { swap.restart() } }
      Connections { target: IslandState
        function onWidgetNameChanged() { if (win.myMode === "widget" && pill.shownWidget !== IslandState.widgetName) swap.restart() } }

      // ---------- idle + hover form (always instantiated: it also reports both widths) ----------
      IdleForm {
        id: idleForm
        win: win
        anchors.fill: parent
        visible: pill.shownMode === "idle" || pill.shownMode === "hover"
        expanded: pill.shownMode === "hover"
      }

      // ---------- HUD form: icon-in-track slider + right-aligned percentage, nothing else ----------
      Item {
        anchors.fill: parent
        visible: pill.shownMode === "hud"
        readonly property bool isText: IslandState.hudMessage !== ""
        readonly property string k: String(IslandState.hudKind || "").toLowerCase()
        property real shown: IslandState.hudValue
        Behavior on shown { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }
        PillSlider {
          visible: !parent.isText
          anchors.fill: parent; anchors.margins: Theme.s8
          height: parent.height - 2 * Theme.s8
          interactive: false; showValue: true
          icon: parent.k.indexOf("bright") === 0 || parent.k === "display" ? "sun"
              : parent.k.indexOf("mic") === 0 ? (IslandState.hudValue <= 0 ? "mic-off" : "mic")
              : parent.k === "charger" ? "bolt" : "info"
          iconItem: parent.k.indexOf("volume") === 0 || parent.k === "mute" ? hudVolume : null
          value: Math.max(0, Math.min(1, parent.shown / 100))
          Component { id: hudVolume; VolumeIcon { level: IslandState.hudValue / 100; muted: IslandState.hudValue <= 0; size: Theme.iconMd; color: Theme.accentText } }
        }
        Row {                                   // text-only HUD (e.g. "Mic muted")
          visible: parent.isText
          anchors.centerIn: parent; spacing: Theme.s8
          Icon { name: parent.parent.k.indexOf("mic") === 0 ? "mic-off" : "info"; size: Theme.iconMd; anchors.verticalCenter: parent.verticalCenter }
          Text { textFormat: Text.PlainText; text: IslandState.hudMessage; color: Theme.text; font.pixelSize: 13; font.bold: true
            anchors.verticalCenter: parent.verticalCenter }
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
        height: item ? item.implicitHeight : Registry.height(pill.shownWidget)
        active: pill.shownMode === "widget"
        focus: true
        source: active && pill.shownWidget !== "" ? "widgets/" + Registry.fileOf(pill.shownWidget) : ""
        onLoaded: {
          item.forceActiveFocus()
          // Widgets that need the window (e.g. tray context menus) declare `hostWindow`.
          if (item.hasOwnProperty("hostWindow")) item.hostWindow = win
        }
      }
    }
  }

  // The 40ms-late height (see below).
  property real delayedH: target.height
  onTargetChanged: {
    if (IslandState.reducedMotion) delayedH = target.height
    else heightGate.restart()
  }
  // Width leads, height follows ~40ms later: `height` springs toward `delayedH`,
  // which a 40ms timer copies from the real target. That is imperative code on
  // purpose; a pure binding can't express "later".
  Timer { id: heightGate; interval: 40; onTriggered: win.delayedH = win.target.height }
}
