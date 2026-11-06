import QtQuick
import Quickshell.Services.Mpris
import ".."
import "../services"

// Media: the active MPRIS player. Title (with a browser's "(3) " unread counter
// stripped), artist if there is one, the player name as a small muted source label,
// controls with a dominant play/pause, and a thin progress slider.
// Keys: Space play/pause · N next · P previous · ←/→ seek ±5 s · Tab next player.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "Space play/pause · N next · P previous · ←/→ seek · Tab player · Esc close"
  property int idx: 0
  readonly property var players: Mpris.players.values
  readonly property var p: players.length > 0 ? players[Math.min(idx, players.length - 1)] : null
  readonly property string title: p ? String(p.trackTitle || "").replace(/^\(\d+\)\s*/, "") : ""
  readonly property string artist: p ? String(p.trackArtist || "").trim() : ""

  function fmt(sec) { sec = Math.max(0, Math.floor(sec)); return Math.floor(sec / 60) + ":" + ("0" + (sec % 60)).slice(-2) }

  Keys.onPressed: function (e) {
    if (!p) return
    if (e.key === Qt.Key_Space) { if (p.canTogglePlaying) p.togglePlaying(); e.accepted = true }
    else if (e.key === Qt.Key_N) { if (p.canGoNext) p.next(); e.accepted = true }
    else if (e.key === Qt.Key_P) { if (p.canGoPrevious) p.previous(); e.accepted = true }
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
      if (p.canSeek && p.positionSupported) p.position = Math.max(0, Math.min(p.length, p.position + (e.key === Qt.Key_Right ? 5 : -5)))
      e.accepted = true }
    else if (e.key === Qt.Key_Tab) { idx = (idx + 1) % Math.max(1, players.length); e.accepted = true }
  }
  // MPRIS doesn't push the position; ask once a second, only while playing and visible.
  Timer { interval: 1000; repeat: true; running: root.p !== null && root.p.isPlaying; onTriggered: root.p.positionChanged() }

  compact: !p
  Text { visible: !root.p; textFormat: Text.PlainText; text: "Nothing playing"; color: Theme.textMuted; font.pixelSize: 14 }

  Row {
    visible: root.p !== null
    width: parent.width; spacing: Theme.s16
    Rectangle { width: 96; height: 96; radius: Theme.tileRadius; color: Theme.surface; clip: true
      Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
        source: root.p && root.p.trackArtUrl ? root.p.trackArtUrl : ""; visible: status === Image.Ready }
      Icon { anchors.centerIn: parent; name: "music"; size: 32; color: Theme.textMuted; visible: !(root.p && root.p.trackArtUrl) } }
    Column {
      width: parent.width - 96 - Theme.s16; height: 96; spacing: 2
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
        text: root.title; color: Theme.text; font.pixelSize: 16; font.bold: true }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; visible: root.artist !== ""
        text: root.artist; color: Theme.textMuted; font.pixelSize: 13 }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText      // source label, not the artist
        text: root.p ? root.p.identity : ""; color: Theme.textMuted; font.pixelSize: 10; opacity: 0.85 }
      Item { width: 1; height: 4 }
      Row { spacing: Theme.s12
        Repeater {
          model: [ { ic: "prev", act: 0 }, { ic: "play", act: 1 }, { ic: "next", act: 2 } ]
          delegate: Rectangle { required property var modelData
            width: modelData.act === 1 ? 44 : 34; height: width; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.act === 1 ? Theme.accent : Theme.surface
            Icon { anchors.centerIn: parent; size: modelData.act === 1 ? Theme.iconLg - 4 : Theme.iconSm
              name: modelData.act === 1 ? (root.p && root.p.isPlaying ? "pause" : "play") : modelData.ic
              color: modelData.act === 1 ? Theme.accentText : Theme.text }
            MouseArea { anchors.fill: parent; onClicked: {
              if (!root.p) return
              if (modelData.act === 0) root.p.previous(); else if (modelData.act === 2) root.p.next(); else root.p.togglePlaying() } } } } }
    }
  }
  // thin progress slider + times
  Column {
    visible: root.p !== null; width: parent.width; spacing: Theme.s4
    PillSlider { width: parent.width; thin: true; interactive: false
      value: root.p && root.p.length > 0 ? Math.min(1, root.p.position / root.p.length) : 0 }
    Item { width: parent.width; height: 14
      Text { textFormat: Text.PlainText; text: root.p ? root.fmt(root.p.position) : ""; color: Theme.textMuted; font.pixelSize: 10 }
      Text { anchors.right: parent.right; textFormat: Text.PlainText; text: root.p ? root.fmt(root.p.length) : ""; color: Theme.textMuted; font.pixelSize: 10 } }
  }
}
