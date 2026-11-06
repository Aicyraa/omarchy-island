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
