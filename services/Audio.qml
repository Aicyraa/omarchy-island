pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio: volume/mute for the default output and input, plus device lists,
// straight from PipeWire (native, event-driven; no wpctl polling).
Singleton {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  // A PipeWire node's volume only updates if something "tracks" it.
  PwObjectTracker { objects: [root.sink, root.source].filter(function (n) { return n !== null && n !== undefined }) }

  readonly property bool hasSink: sink !== null && sink !== undefined && sink.audio !== null
  readonly property real volume: hasSink ? sink.audio.volume : 0
  readonly property bool muted: hasSink ? sink.audio.muted : false
  readonly property bool hasSource: source !== null && source !== undefined && source.audio !== null
  readonly property real micVolume: hasSource ? source.audio.volume : 0
  readonly property bool micMuted: hasSource ? source.audio.muted : false

  function clamp(v) { return Math.max(0, Math.min(1, v)) }
  function setVolume(v) { if (!hasSink) return; sink.audio.muted = false; sink.audio.volume = clamp(v) }
  function toggleMute() { if (hasSink) sink.audio.muted = !sink.audio.muted }
  function setMicVolume(v) { if (hasSource) source.audio.volume = clamp(v) }
  function toggleMicMute() { if (hasSource) source.audio.muted = !source.audio.muted }

  function label(n) { return n ? (n.description || n.nickname || n.name || "") : "" }

  // Real devices only (not per-app streams).
  function devices(wantSink) {
    var out = [], all = Pipewire.nodes.values
    for (var i = 0; i < all.length; i++) {
      var n = all[i]
      if (n.isStream || !n.audio || n.isSink !== wantSink) continue
      out.push(n)
    }
    return out
  }
  readonly property var sinks: devices(true)
  readonly property var sources: devices(false)

  function setDefaultSink(n) { Pipewire.preferredDefaultAudioSink = n }
  function setDefaultSource(n) { Pipewire.preferredDefaultAudioSource = n }
}
