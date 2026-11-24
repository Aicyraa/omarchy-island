pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../QuickshellDS/Theme"

// WidgetSurface: standardized QuickshellDS container for every Island widget.
// Computes content-sized implicitWidth / implicitHeight with generous horizontal padding,
// exposes `scrollTarget` for the detached sibling ScrollRail in IslandWindow, and
// supports optional keyboard hints & reserve anti-snap height.
Item {
  id: panel

  default property alias content: col.data
  property string hint: ""
  property real preferredWidth: 500
  property bool compact: false
  property Flickable scrollTarget: null
  property alias flick: innerFlick

  // Focus compatibility properties
  readonly property bool focusHost: true
  property Item focusItem: null
  readonly property var column: col

  // Generous asymmetric padding (horizontal > vertical per QuickshellDS)
  property real hPad: Tokens.space.xl
  property real vPad: Tokens.space.lg
  readonly property int pad: Math.round(vPad)

  readonly property real maxWidth: Math.min(Tokens.px(940), 940)
  readonly property real maxHeight: Math.min(Tokens.px(560), 560)
  readonly property real minHeight: compact ? Tokens.px(64) : Tokens.px(120)

  property bool dataLoading: false
  property bool useReserve: true
  property real reserve: 0
  readonly property bool reserving: useReserve && (dataLoading || Quickshell.env("ISLAND_FORCE_LOADING") === "1") && reserve > 0 && reserveTimer.running
  Timer { id: reserveTimer; interval: 2500; running: true }

  readonly property real contentH: col.implicitHeight + 2 * vPad
  readonly property bool scrollable: scrollTarget === null && contentH > height + 1
  readonly property Flickable effectiveScrollTarget: panel.scrollTarget || (panel.scrollable ? innerFlick : null)

  focus: true
  implicitWidth: Math.min(maxWidth, preferredWidth)
  implicitHeight: Math.max(minHeight, Math.min(maxHeight, reserving ? Math.max(contentH, reserve) : contentH))

  function reveal(item) {
    if (!item) return
    var target = scrollTarget || innerFlick
    var p = item.mapToItem(target.contentItem, 0, 0)
    var top = p.y - Tokens.space.sm
    var bottom = p.y + item.height + Tokens.space.sm
    if (top < target.contentY) target.contentY = Math.max(0, top)
    else if (bottom > target.contentY + target.height)
      target.contentY = Math.max(0, Math.min(target.contentHeight - target.height, bottom - target.height))
  }

  Flickable {
    id: innerFlick
    x: panel.hPad
    y: panel.vPad
    width: Math.max(0, panel.width - 2 * panel.hPad)
    height: Math.max(0, panel.height - 2 * panel.vPad)
    contentWidth: width
    contentHeight: col.implicitHeight
    clip: panel.scrollable
    boundsBehavior: Flickable.StopAtBounds
    interactive: panel.scrollable

    Column {
      id: col
      width: innerFlick.width
      spacing: Tokens.space.md
    }
  }
}
