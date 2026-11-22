import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import ".."
import "../services"

// The media player card on the Home widget. It is always shown: with a player it is the track (art as the
// background, cover, title, controls, spectrum, progress); with none it is a quiet placeholder of the same size,
// so the Home layout never jumps when playback starts or stops.
//
// Geometry (the card is 216 x 144; the inner area is 192 x 120 after a 12 px margin):
//   cover 64 x 64 at (0, 0) · text from x 76 · controls at y 36 · times y 70 · scrub/visualizer y 84..118.
Item {
  id: root
  property var p: null                         // an MprisPlayer, or null for the placeholder
  property bool live: true                     // card on screen (position ticks + visualizer run only then)
  readonly property bool empty: p === null
  // Browsers put "(3) Artist - Song (Official Video) - YouTube" in the title and send no artist or art.
  // Track changes bump `rev`, so every track-dependent value below is re-read from the player at once
  // instead of trusting that a property binding saw the change (the card went stale on the next song).
  property int rev: 0
  Connections {
    target: root.p
    ignoreUnknownSignals: true
    function onTrackChanged() { root.rev++ }
    function onPostTrackChanged() { root.rev++ }
    function onMetadataChanged() { root.rev++ }
    function onTrackTitleChanged() { root.rev++ }
    function onTrackArtistChanged() { root.rev++ }
    function onTrackArtUrlChanged() { root.rev++ }
    function onIsPlayingChanged() { root.rev++ }
  }
  readonly property string rawTitle: { root.rev; return p ? String(p.trackTitle || "").replace(/^\(\d+\)\s*/, "").replace(/\s+-\s+YouTube( Music)?$/, "") : "" }
  // Drop the " | Label, City (2018)" tail and every bracketed part: the search needs "artist title", and iTunes
  // returns nothing for a term that still carries those (that is why YouTube tracks had no cover).
  readonly property string cleanTitle: rawTitle.replace(/\|.*$/, "").replace(/\s*[\(\[][^\)\]]*[\)\]]/g, "").replace(/\s+/g, " ").trim()
  readonly property string artist0: { root.rev; return p ? String(p.trackArtist || "").trim() : "" }
  readonly property bool splitTitle: artist0 === "" && cleanTitle.indexOf(" - ") > 0
  readonly property string artist: splitTitle ? cleanTitle.slice(0, cleanTitle.indexOf(" - ")) : artist0
  readonly property string title: splitTitle ? cleanTitle.slice(cleanTitle.indexOf(" - ") + 3) : cleanTitle
  readonly property string term: title === "" ? "" : (artist + " " + title).trim()
  readonly property bool wantLookup: live && p !== null && !(p.trackArtUrl) && term !== ""
  Component.onCompleted: if (wantLookup) ArtLookup.request(term)
  onWantLookupChanged: if (wantLookup) ArtLookup.request(term)
  onTermChanged: if (wantLookup) ArtLookup.request(term)
  readonly property string art: { root.rev; return p && p.trackArtUrl ? String(p.trackArtUrl) : (ArtLookup.cache[term] || "") }
  readonly property bool hasArt: art !== "" && bg.status === Image.Ready
  // Over art the text is always light (the scrim guarantees it); without art it follows the theme.
  readonly property color fg: hasArt ? Qt.rgba(1, 1, 1, 0.96) : Theme.text
  readonly property color fgMuted: hasArt ? Qt.rgba(1, 1, 1, 0.72) : Theme.textMuted

  implicitWidth: 216
  implicitHeight: 144
  property alias visualizer: viz
  function fmt(sec) { sec = Math.max(0, Math.floor(sec)); return Math.floor(sec / 60) + ":" + ("0" + (sec % 60)).slice(-2) }

  // MPRIS doesn't push the position; ask once a second while playing and visible.
  Timer { interval: 1000; repeat: true; running: root.live && root.p !== null && root.p.isPlaying; onTriggered: root.p.positionChanged() }

  // ---------- background ----------
  // With a track: the art, blurred and darkened. Empty: a calm tint of the theme, with a hairline edge.
  ClippingRectangle {
    anchors.fill: parent; radius: Theme.tileRadius; color: Theme.surface
    Image {
      id: bg
      anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
      sourceSize.width: 480; sourceSize.height: 480
      source: root.art; visible: false
    }
    MultiEffect {
      anchors.centerIn: parent; width: parent.width * 1.15; height: parent.height * 1.15   // overscan hides blur edges
      source: bg; visible: root.hasArt
      blurEnabled: true; blur: 0.55; blurMax: 32; saturation: 0.15
    }
    Rectangle {                                // scrim: darker at the left (text) and bottom (controls)
      anchors.fill: parent; visible: root.hasArt
      gradient: Gradient { orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.62) }
        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.38) } }
    }
    Rectangle {                                // placeholder: a soft wash from the surface toward the accent
      anchors.fill: parent; visible: root.empty
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.surface }
        GradientStop { position: 1; color: Theme.mix(Theme.surface, Theme.accentFill, 0.14) } }
    }
  }
  Rectangle {                                  // hairline edge (the placeholder, and the art card in the theme's line colour)
    anchors.fill: parent; radius: Theme.tileRadius; color: "transparent"
    border.width: 1; border.color: Theme.mix(Theme.surface, Theme.text, root.empty ? 0.10 : 0.06)
  }

  Item {
    anchors.fill: parent; anchors.margins: 12

    // ---------- cover: the art, or a vinyl record (spinning while a track plays) ----------
    ClippingRectangle {
      id: cover
      width: 64; height: 64; radius: 12; color: "transparent"
      Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; source: root.art
        sourceSize.width: 320; sourceSize.height: 320; visible: status === Image.Ready }
    }
    Vinyl { anchors.fill: cover; visible: !root.hasArt; spinning: root.p !== null && root.p.isPlaying && root.live
      opacity: root.empty ? 0.5 : 1 }

    // ---------- title + artist ----------
    Column {
      x: cover.width + 12; y: 0; width: parent.width - x; spacing: 2
      Label { width: parent.width; elide: Text.ElideRight
        text: root.empty ? "Nothing playing" : (root.title !== "" ? root.title : "Unknown title")
        color: root.fg; font.pixelSize: Theme.typeTitle; font.weight: Theme.weightStrong }
      Label { width: parent.width; elide: Text.ElideRight
        text: root.empty ? "Waiting for music" :(root.artist !== "" ? root.artist : (root.p ? root.p.identity : ""))
        color: root.fgMuted; font.pixelSize: Theme.typeLabel }
    }

    // ---------- controls: the same three buttons, dimmed and inert in the placeholder ----------
    Row {
      id: controls
      x: cover.width + 12; y: 36; spacing: Theme.s8
      opacity: root.empty ? 0.35 : 1
      Repeater {
        model: [ { ic: "prev", act: 0 }, { ic: "play", act: 1 }, { ic: "next", act: 2 } ]
        delegate: Rectangle { required property var modelData
          width: modelData.act === 1 ? 34 : 28; height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: modelData.act === 1 ? Theme.accentFill : Qt.rgba(1, 1, 1, root.hasArt ? 0.16 : 0.08)
          Icon { anchors.centerIn: parent; size: modelData.act === 1 ? Theme.iconMd : Theme.iconSm
            name: modelData.act === 1 ? (root.p && root.p.isPlaying ? "pause" : "play") : modelData.ic
            color: modelData.act === 1 ? Theme.accentText : root.fg }
          MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.p !== null; onClicked: {
            if (modelData.act === 0) root.p.previous(); else if (modelData.act === 2) root.p.next(); else root.p.togglePlaying() } } }
      }
    }

    // ---------- scrub: the visualizer is the progress bar. It grows up and down from a centre line, and the bars
    // past the playhead are dimmed. The elapsed time rides above the playhead, the total sits at the right end.
    // Click or drag on it to seek, when the player allows it. Resting dots in the placeholder. ----------
    Item {
      id: scrub
      x: 0; y: 70; width: parent.width; height: 48
      readonly property bool seekable: root.p !== null && root.p.canSeek && root.p.lengthSupported && root.p.length > 0
      readonly property real frac: root.p && root.p.length > 0 ? Math.min(1, root.p.position / root.p.length) : 0
      function seekTo(x) { if (seekable) root.p.position = Math.max(0, Math.min(1, x / width)) * root.p.length }

      Label {
        id: elapsed
        visible: !root.empty; y: 0
        x: 0                                        // fixed at the left: the start time never moves
        mono: true; text: root.p ? root.fmt(root.p.position) : ""
        color: root.fg; font.pixelSize: Theme.typeCaption
      }
      Label {
        id: total
        visible: !root.empty                        // fixed at the right end
        anchors.right: parent.right; y: 0
        mono: true; text: root.p ? root.fmt(root.p.length) : ""
        color: root.fg; font.pixelSize: Theme.typeCaption
      }

      Visualizer {
        id: viz
        anchors.left: parent.left; anchors.right: parent.right
        y: 14; height: 34; bars: 24                 // bars must equal `bars` in assets/cava.conf, or the extra bars never move
        mirror: true; progress: root.empty ? -1 : scrub.frac
        color: root.hasArt ? Qt.rgba(1, 1, 1, 0.9) : Theme.accentFill
        opacity: root.empty ? 0.4 : 1
        active: root.live && root.p !== null && root.p.isPlaying
      }
      MouseArea {
        x: 0; y: viz.y - 6; width: scrub.width; height: viz.height + 12
        enabled: scrub.seekable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onPressed: function (m) { scrub.seekTo(m.x) }
        onPositionChanged: function (m) { if (pressed) scrub.seekTo(m.x) }
      }
    }
  }
}
