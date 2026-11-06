import QtQuick
import Quickshell.Services.Mpris
import ".."
import "../services"

// Media: the active MPRIS player on the shared MediaCard (blurred art background, visualizer, controls).
// Keys: Space play/pause · N next · P previous · ←/→ seek ±5 s · Tab next player.
WidgetPanel {
  id: root
  preferredWidth: 480
  hint: "Space play/pause · N next · P previous · ←/→ seek · Tab player · Esc close"
  property int idx: 0
  readonly property var players: Mpris.players.values
  readonly property var p: players.length > 0 ? players[Math.min(idx, players.length - 1)] : null

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
  compact: !p
  Text { visible: !root.p; textFormat: Text.PlainText; text: "Nothing playing"; color: Theme.textMuted; font.pixelSize: 14 }
  MediaCard { visible: root.p !== null; width: parent.width; p: root.p }
}
