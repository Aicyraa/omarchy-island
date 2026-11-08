import QtQuick
import ".."

// The sliding highlight lives in the scrolled content, behind the rows. It is a rectangle whose TOP and BOTTOM edges
// (for lists) move on their own clocks: the edge that leads the motion is quick (200 ms) and the trailing edge follows
// slower (320 ms), so the highlight stretches while it travels and then settles, like a drop of liquid. Both edges
// start from wherever the highlight currently is, so a second move mid-flight never jumps. Horizontal edges follow the
// same rule. It bleeds 8 px sideways like the rows do.
Rectangle {
  id: hl
  // what it follows: the focused item, the coordinate space it lives in, and the column it re-places on
  property Item host: null
  property Item container: null
  property Item content: null
  readonly property bool has: host.focusItem !== null && host.focusItem.visible
  // current geometry: derived from the edges and the two progress values
  property real fL: 0; property real fR: 0; property real fT: 0; property real fB: 0      // edges where this move started
  property real tL: 0; property real tR: 0; property real tT: 0; property real tB: 0      // edges it is moving to
  property real pHead: 1; property real pTail: 1                                          // 0..1 progress of each clock
  property bool goDown: true; property bool goRight: true
  readonly property real eL: fL + (tL - fL) * (goRight ? pTail : pHead)
  readonly property real eR: fR + (tR - fR) * (goRight ? pHead : pTail)
  readonly property real eT: fT + (tT - fT) * (goDown ? pTail : pHead)
  readonly property real eB: fB + (tB - fB) * (goDown ? pHead : pTail)
  x: eL; y: eT; width: Math.max(0, eR - eL); height: Math.max(0, eB - eT)
  radius: Theme.tileRadius; color: Qt.rgba(Theme.accentFill.r, Theme.accentFill.g, Theme.accentFill.b, 0.16)   // a soft accent glow: translucent, so it also reads over cards
  z: 1
  opacity: has ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: IslandState.reducedMotion ? 0 : 140 } }

  function place(first) {
    var it = host.focusItem
    if (!it) return
    var p = it.mapToItem(container, 0, 0)
    var nL = p.x - Theme.s8, nT = p.y, nR = p.x + it.width + Theme.s8, nB = p.y + it.height
    if (first || IslandState.reducedMotion) {
      fL = tL = nL; fR = tR = nR; fT = tT = nT; fB = tB = nB
      pHead = 1; pTail = 1
      return
    }
    // start the new move from the CURRENT (possibly half-way) edges
    fL = eL; fR = eR; fT = eT; fB = eB
    tL = nL; tR = nR; tT = nT; tB = nB
    goDown = tB >= fB; goRight = tR >= fR
    pHead = 0; pTail = 0
    moveAnim.restart()
  }
  ParallelAnimation {
    id: moveAnim
    NumberAnimation { target: hl; property: "pHead"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { target: hl; property: "pTail"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
  }
  property bool wasHas: false
  onHasChanged: if (has) { place(!wasHas); wasHas = true } else wasHas = false
  Connections { target: host; function onFocusItemChanged() { hl.place(false) } }
  Connections { target: host.focusItem; ignoreUnknownSignals: true
    function onYChanged() { hl.place(false) } function onHeightChanged() { hl.place(false) } function onWidthChanged() { hl.place(false) } }
  Connections { target: content; function onImplicitHeightChanged() { hl.place(false) } }
}
