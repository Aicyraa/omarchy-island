import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../../QuickshellDS/Theme"
import "../../../assets/GlobeModel.js" as Solar

// An interactive globe: drag to spin it. Land comes from assets/world.json (Omarchy's Elsewhen data), the night side is
// shaded from the real sun position (recomputed every minute), your cities are dots and the selected one is ringed.
// `focusLon` turns the globe (by the short way round) to face a longitude; dragging takes over until it changes again.
Item {
  id: root
  property var markers: []                  // [{ lat, lon, sel }]
  property real focusLon: 0
  property real spin: 0
  property bool dragging: false
  readonly property real viewLat: 14        // tilted a little towards the north, like a desk globe
  property var land: []

  implicitWidth: 156; implicitHeight: 156

  function css(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }
  onSpinChanged: canvas.requestPaint()
  onMarkersChanged: canvas.requestPaint()
  Connections { target: Tokens.color; function onTextMutedChanged() { canvas.requestPaint() } function onAccentChanged() { canvas.requestPaint() } function onIslandGroundChanged() { canvas.requestPaint() } }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: canvas.requestPaint() }

  // turn to face a longitude the short way round
  onFocusLonChanged: {
    if (dragging) return
    var d = ((focusLon - spin + 540) % 360) - 180
    turn.stop(); turn.from = spin; turn.to = spin + d; turn.start()
  }
  NumberAnimation { id: turn; target: root; property: "spin"; duration: IslandState.reducedMotion ? 0 : 800; easing.type: Easing.InOutCubic }

  FileView { path: Qt.resolvedUrl("../../../assets/world.json").toString().replace("file://", ""); printErrors: false
    onLoaded: { try { root.land = JSON.parse(text()); canvas.requestPaint() } catch (e) {} } }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var W = width, H = height, r = Math.min(W, H) / 2 - 2
      if (r <= 0) return
      ctx.translate(W / 2, H / 2)
      var spin = root.spin, vl = root.viewLat

      // ocean
      ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2)
      ctx.fillStyle = root.css(Qt.rgba(Tokens.color.accent.r * 0.30 + Tokens.color.islandGround.r * 0.70, Tokens.color.accent.g * 0.30 + Tokens.color.islandGround.g * 0.70, Tokens.color.accent.b * 0.30 + Tokens.color.islandGround.b * 0.70, 1), 1); ctx.fill()

      ctx.save()
      ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.clip()

      // graticule
      ctx.beginPath()
      var lat, lon, pts, segs, i, j
      function stroke(pts) {
        segs = Solar.visibleSegments(pts, spin, vl, r)
        for (i = 0; i < segs.length; i++) { ctx.moveTo(segs[i][0].x, segs[i][0].y); for (j = 1; j < segs[i].length; j++) ctx.lineTo(segs[i][j].x, segs[i][j].y) }
      }
      for (lon = -180; lon < 180; lon += 30) { pts = []; for (lat = -90; lat <= 90; lat += 6) pts.push([lat, lon]); stroke(pts) }
      for (lat = -60; lat <= 60; lat += 30) { pts = []; for (lon = -180; lon <= 180; lon += 6) pts.push([lat, lon]); stroke(pts) }
      ctx.lineWidth = 0.6; ctx.strokeStyle = root.css(Tokens.color.text, 0.10); ctx.stroke()

      // land
      if (root.land.length > 0) {
        ctx.beginPath()
        for (i = 0; i < root.land.length; i++) {
          var ring = root.land[i]
          if (ring.length < 24) continue
          var poly = Solar.clipRingToDisc(ring, spin, vl, r)
          if (poly.length < 3) continue
          ctx.moveTo(poly[0].x, poly[0].y)
          for (var q = 1; q < poly.length; q++) ctx.lineTo(poly[q].x, poly[q].y)
          ctx.closePath()
        }
        ctx.fillStyle = root.css(Qt.rgba(Tokens.color.text.r * 0.25 + Tokens.color.textMuted.r * 0.75, Tokens.color.text.g * 0.25 + Tokens.color.textMuted.g * 0.75, Tokens.color.text.b * 0.25 + Tokens.color.textMuted.b * 0.75, 1), 0.78); ctx.fill()
      }

      // night side: the real sun position (updated every minute). The terminator is a great circle, drawn as the visible half of
      // its (elliptical) projection closed along the limb on the night side: one filled shape, no per-pixel work.
      var sub = Solar.subsolarPoint(Date.now())
      var DEG = Math.PI / 180, p0 = vl * DEG, sl = sub.lat * DEG, dl = (sub.lon - spin) * DEG
      var sx = Math.cos(sl) * Math.sin(dl)
      var sy = Math.cos(p0) * Math.sin(sl) - Math.sin(p0) * Math.cos(sl) * Math.cos(dl)
      var sz = Math.sin(p0) * Math.sin(sl) + Math.cos(p0) * Math.cos(sl) * Math.cos(dl)
      var mm = Math.sqrt(sx * sx + sy * sy)
      ctx.beginPath()
      if (mm < 1e-3) { if (sz < 0) ctx.arc(0, 0, r, 0, Math.PI * 2) }
      else {
        var ax = -sy / mm, ay = sx / mm, bx = -sz * sx / mm, by = -sz * sy / mm
        ctx.moveTo(ax * r, -ay * r)
        for (var kk = 1; kk <= 48; kk++) {
          var tt = kk / 48 * Math.PI, ct = Math.cos(tt), st = Math.sin(tt)
          ctx.lineTo((ax * ct + bx * st) * r, -(ay * ct + by * st) * r)
        }
        var aA = Math.atan2(-ay, ax), aN = aA + Math.PI, phi = Math.atan2(sy, -sx)
        var rel = ((phi - aN) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI)
        ctx.arc(0, 0, r, aN, aA, rel >= Math.PI)
        ctx.closePath()
      }
      ctx.fillStyle = "rgba(4, 8, 22, 0.55)"; ctx.fill()

      // cities
      for (i = 0; i < root.markers.length; i++) {
        var m = root.markers[i], p = Solar.project(m.lat, m.lon, spin, vl, r)
        if (!p.visible) continue
        ctx.beginPath(); ctx.arc(p.x, p.y, m.sel ? 3.4 : 2.2, 0, Math.PI * 2)
        ctx.fillStyle = m.sel ? root.css(Tokens.color.warning, 1) : root.css(Tokens.color.text, 0.9); ctx.fill()
        if (m.sel) { ctx.beginPath(); ctx.arc(p.x, p.y, 7, 0, Math.PI * 2); ctx.lineWidth = 1.2; ctx.strokeStyle = root.css(Tokens.color.warning, 0.7); ctx.stroke() }
      }
      ctx.restore()

      // rim
      ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.lineWidth = 1.2; ctx.strokeStyle = root.css(Tokens.color.text, 0.35); ctx.stroke()
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property real startX: 0; property real startSpin: 0
    onPressed: function (m) { turn.stop(); root.dragging = true; startX = m.x; startSpin = root.spin }
    onPositionChanged: function (m) { if (pressed) root.spin = startSpin - (m.x - startX) * 0.7 }
    onReleased: root.dragging = false
    onCanceled: root.dragging = false
  }
}
