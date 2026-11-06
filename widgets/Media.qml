import QtQuick
import Quickshell.Services.Mpris
import ".."
import "../services"

// Media: the active MPRIS player (Spotify, browsers, mpv...).
// Keys: Space play/pause · N next · P previous · ←/→ seek ±5 s · Tab next player.
Item {
  id: root
  focus: true
  property string hint: "Space play/pause · N next · P previous · ←/→ seek · Tab player · Esc close"
  property int idx: 0
  readonly property var players: Mpris.players.values
  readonly property var p: players.length > 0 ? players[Math.min(idx, players.length - 1)] : null

  function fmt(sec) { sec = Math.max(0, Math.floor(sec)); return Math.floor(sec / 60) + ":" + ("0" + (sec % 60)).slice(-2) }

  Keys.onPressed: function (e) {
    if (!p) return
    if (e.key === Qt.Key_Space) { if (p.canTogglePlaying) p.togglePlaying(); e.accepted = true }
    else if (e.key === Qt.Key_N) { if (p.canGoNext) p.next(); e.accepted = true }
    else if (e.key === Qt.Key_P) { if (p.canGoPrevious) p.previous(); e.accepted = true }
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
      if (p.canSeek && p.positionSupported) { p.position = Math.max(0, Math.min(p.length, p.position + (e.key === Qt.Key_Right ? 5 : -5))) }
      e.accepted = true }
    else if (e.key === Qt.Key_Tab) { idx = (idx + 1) % Math.max(1, players.length); e.accepted = true }
  }

  // Position isn't pushed by MPRIS; ask for it once a second, and only while playing and visible.
  Timer { interval: 1000; repeat: true; running: root.p !== null && root.p.isPlaying; onTriggered: root.p.positionChanged() }

  Text { visible: !root.p; anchors.centerIn: parent; textFormat: Text.PlainText
    text: "Nothing playing"; color: Theme.textMuted; font.pixelSize: 14 }

  Item { visible: root.p !== null; anchors.fill: parent
    Rectangle { x: 20; y: 20; width: 120; height: 120; radius: 20; color: Theme.surface; clip: true
      Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
        source: root.p && root.p.trackArtUrl ? root.p.trackArtUrl : "" ; visible: status === Image.Ready }
      Icon { anchors.centerIn: parent; name: "music"; size: 34; color: Theme.textMuted; visible: !(root.p && root.p.trackArtUrl) } }
    Column { x: 156; y: 24; width: root.width - 156 - 20; spacing: 4
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
        text: root.p ? root.p.trackTitle : ""; color: Theme.text; font.pixelSize: 17; font.bold: true }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
        text: root.p ? root.p.trackArtist : ""; color: Theme.textMuted; font.pixelSize: 13 }
      Text { textFormat: Text.PlainText; text: root.p ? root.p.identity : ""; color: Theme.textMuted; font.pixelSize: 10 } }

    Row { x: 156; y: 100; spacing: 12
      Repeater {
        model: [ { ic: "prev", act: 0 }, { ic: "play", act: 1 }, { ic: "next", act: 2 } ]
        delegate: Rectangle { required property var modelData
          width: modelData.act === 1 ? 44 : 36; height: width; radius: width / 2
          color: modelData.act === 1 ? Theme.accent : Theme.surface
          Icon { anchors.centerIn: parent; size: 18
            name: modelData.act === 1 ? (root.p && root.p.isPlaying ? "pause" : "play") : modelData.ic
            color: modelData.act === 1 ? Theme.accentText : Theme.text }
          MouseArea { anchors.fill: parent; onClicked: {
            if (!root.p) return
            if (modelData.act === 0) root.p.previous(); else if (modelData.act === 2) root.p.next(); else root.p.togglePlaying() } } } } }

    // progress
    Rectangle { x: 20; y: 156; width: root.width - 40; height: 6; radius: 3; color: Theme.surface
      Rectangle { height: parent.height; radius: 3; color: Theme.accent
        width: root.p && root.p.length > 0 ? parent.width * Math.min(1, root.p.position / root.p.length) : 0 } }
    Text { x: 20; y: 168; textFormat: Text.PlainText; text: root.p ? root.fmt(root.p.position) : ""; color: Theme.textMuted; font.pixelSize: 10 }
    Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 168; textFormat: Text.PlainText
      text: root.p ? root.fmt(root.p.length) : ""; color: Theme.textMuted; font.pixelSize: 10 }
  }
}
