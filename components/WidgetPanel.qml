import QtQuick
import ".."

// WidgetPanel: the base every widget is built on. It is what makes panels
// CONTENT-SIZED instead of fixed-height.
//
//   * Put the widget's content inside it (it is the default property, so children
//     land in the inner Column). Each child gets the full inner width.
//   * implicitHeight = content + 2 * panelPadding, clamped to
//     [panelMinHeight, panelMaxHeight]. Island reads implicitWidth/implicitHeight
//     from the active widget and springs the pill to that size.
//   * Taller content scrolls inside a Flickable, with a fade at each clipped edge
//     and a thin scroll indicator. reveal(item) scrolls a selected item into view.
Item {
  id: panel

  default property alias content: col.data
  property string hint: ""                 // optional description of the widget's keys (no longer drawn)
  property real preferredWidth: 480
  property bool compact: false             // small toast: tighter minimum height
  property alias flick: flick
  // The shared, animated focus highlight (see FocusTarget): rows register themselves here.
  readonly property bool focusHost: true
  property Item focusItem: null
  readonly property var column: col        // exposed for the layout measurement tool

  readonly property int pad: Theme.panelPadding
  // The scrolling area is inset by `inset` at the top and bottom, so when a long list scrolls its
  // rows are clipped 8px BEFORE the pill edge instead of flush against it. The column's own
  // top/bottom padding shrinks by the same amount, so the resting padding is still exactly `pad`.
  readonly property int inset: Theme.s8
  readonly property real contentH: col.implicitHeight + 2 * pad

  focus: true
  implicitWidth: preferredWidth
  implicitHeight: Math.max(compact ? 40 : Theme.panelMinHeight, Math.min(Theme.panelMaxHeight, contentH))
  readonly property bool scrollable: contentH > height + 1

  function reveal(item) {
    if (!item) return
    var p = item.mapToItem(col, 0, 0)
    var top = p.y + (pad - inset) - Theme.s8, bottom = p.y + (pad - inset) + item.height + Theme.s8
    if (top < flick.contentY) flick.contentY = Math.max(0, top)
    else if (bottom > flick.contentY + flick.height) flick.contentY = Math.min(flick.contentHeight - flick.height, bottom - flick.height)
  }

  Flickable {
    id: flick
    y: panel.inset
    width: panel.width
    height: panel.height - 2 * panel.inset
    contentWidth: width
    contentHeight: col.implicitHeight + 2 * (panel.pad - panel.inset)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: panel.scrollable
    Behavior on contentY { enabled: !flick.moving && !flick.dragging && !bar.dragging; NumberAnimation { duration: IslandState.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }

    // The sliding highlight lives in the scrolled content, behind the rows. It bleeds 8px like the old per-row one.
    Rectangle {
      id: hl
      readonly property bool has: panel.focusItem !== null && panel.focusItem.visible
      property real tx: 0; property real ty: 0; property real tw: 0; property real th: 0
      function place() {
        var it = panel.focusItem; if (!it) return
        var p = it.mapToItem(flick.contentItem, 0, 0)
        tx = p.x - Theme.s8; ty = p.y; tw = it.width + 2 * Theme.s8; th = it.height
      }
      Connections { target: panel; function onFocusItemChanged() { hl.place() } }
      Connections { target: panel.focusItem; ignoreUnknownSignals: true
        function onYChanged() { hl.place() } function onHeightChanged() { hl.place() } function onWidthChanged() { hl.place() } }
      Connections { target: col; function onImplicitHeightChanged() { hl.place() } }
      x: tx; y: ty; width: tw; height: th
      radius: Theme.tileRadius; color: Theme.surfaceRaised
      opacity: has ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140 } }
      // Slides and resizes with a small overshoot. The first placement (no previous item) just appears.
      Behavior on x { enabled: hl.has && !IslandState.reducedMotion; SpringAnimation { spring: 6.5; damping: 0.45; epsilon: 0.3 } }
      Behavior on y { enabled: hl.has && !IslandState.reducedMotion; SpringAnimation { spring: 6.5; damping: 0.45; epsilon: 0.3 } }
      Behavior on width { enabled: hl.has && !IslandState.reducedMotion; SpringAnimation { spring: 6.5; damping: 0.45; epsilon: 0.3 } }
      Behavior on height { enabled: hl.has && !IslandState.reducedMotion; SpringAnimation { spring: 6.5; damping: 0.45; epsilon: 0.3 } }
    }

    Column {
      id: col
      x: panel.pad; y: panel.pad - panel.inset
      width: panel.width - 2 * panel.pad
      spacing: Theme.sectionGap
    }
  }

  // ---- scroll cues: fades at the clipped edges + a thin indicator ----
  Rectangle { visible: panel.scrollable && flick.contentY > 2; width: panel.width; height: 22; y: flick.y
    gradient: Gradient { GradientStop { position: 0; color: Theme.pill } GradientStop { position: 1; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } } }
  Rectangle { visible: panel.scrollable && flick.contentY < flick.contentHeight - flick.height - 2
    width: panel.width; height: 22; y: flick.y + flick.height - 22
    gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } GradientStop { position: 1; color: Theme.pill } } }
  Scroller { id: bar; flick: flick; visible: panel.scrollable; x: panel.width - 16; width: 16; y: flick.y; height: flick.height }
}
