import QtQuick
import ".."

// WidgetPanel: the base every widget is built on. It is what makes panels
// CONTENT-SIZED instead of fixed-height.
//
//   * Put the widget's content inside it (it is the default property, so children
//     land in the inner Column). Each child gets the full inner width.
//   * implicitHeight = content + 2 * panelPadding + footer, clamped to
//     [panelMinHeight, panelMaxHeight]. Island reads implicitWidth/implicitHeight
//     from the active widget and springs the pill to that size.
//   * Taller content scrolls inside a Flickable, with a fade at each clipped edge
//     and a thin scroll indicator. reveal(item) scrolls a selected item into view.
//   * The key-hint footer is part of the panel (same height and style everywhere).
Item {
  id: panel

  default property alias content: col.data
  property string hint: ""
  property real preferredWidth: 480
  property bool compact: false            // small toast: no footer, tight min height
  property alias flick: flick
  readonly property var column: col        // exposed for the layout measurement tool

  readonly property int pad: Theme.panelPadding
  readonly property bool showFooter: !compact && hint !== "" && IslandState.hintsVisible
  readonly property real footerH: showFooter ? Theme.footerHeight : 0
  readonly property real contentH: col.implicitHeight + 2 * pad

  focus: true
  implicitWidth: preferredWidth
  implicitHeight: Math.max(compact ? 40 : Theme.panelMinHeight, Math.min(Theme.panelMaxHeight, contentH + footerH))

  readonly property bool scrollable: contentH > height - footerH + 1

  function reveal(item) {
    if (!item) return
    var p = item.mapToItem(col, 0, 0)
    var top = p.y + pad - Theme.s8, bottom = p.y + pad + item.height + Theme.s8
    if (top < flick.contentY) flick.contentY = Math.max(0, top)
    else if (bottom > flick.contentY + flick.height) flick.contentY = Math.min(flick.contentHeight - flick.height, bottom - flick.height)
  }

  Flickable {
    id: flick
    width: panel.width
    height: panel.height - panel.footerH
    contentWidth: width
    contentHeight: panel.contentH
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: panel.scrollable
    Behavior on contentY { enabled: !flick.moving && !flick.dragging; NumberAnimation { duration: IslandState.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }

    Column {
      id: col
      x: panel.pad; y: panel.pad
      width: panel.width - 2 * panel.pad
      spacing: Theme.sectionGap
    }
  }

  // ---- scroll cues: fades at the clipped edges + a thin indicator ----
  Rectangle { visible: panel.scrollable && flick.contentY > 2; width: panel.width; height: 22; y: 0
    gradient: Gradient { GradientStop { position: 0; color: Theme.pill } GradientStop { position: 1; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } } }
  Rectangle { visible: panel.scrollable && flick.contentY < flick.contentHeight - flick.height - 2
    width: panel.width; height: 22; y: flick.height - 22
    gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0) } GradientStop { position: 1; color: Theme.pill } } }
  Rectangle { visible: panel.scrollable
    x: panel.width - 5; width: 3; radius: 1.5; color: Theme.outline; opacity: 0.7
    height: Math.max(24, flick.height * flick.height / flick.contentHeight)
    y: flick.contentHeight > flick.height ? (flick.height - height) * flick.contentY / (flick.contentHeight - flick.height) : 0 }

  // ---- footer: key hints ----
  Text {
    visible: panel.showFooter
    x: panel.pad; width: panel.width - 2 * panel.pad
    y: panel.height - Theme.footerHeight; height: Theme.footerHeight
    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    textFormat: Text.PlainText; text: panel.hint
    color: Theme.textMuted; font.pixelSize: 11
  }
}
