import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import ".."
import "../services"

// The media player card, shared by the hover preview and the Media widget.
// The track's art is the card background (cover-cropped, lightly blurred, darkened by a scrim so the
// text stays readable on any cover). Real spectrum visualizer, controls, thin progress.
Item {
  id: root
  property var p: null                         // an MprisPlayer
  property bool live: true                     // card on screen (position ticks + visualizer run only then)
  // Browsers put "(3) Artist - Song (Official Video) - YouTube" in the title and send no artist or art.
  readonly property string rawTitle: p ? String(p.trackTitle || "").replace(/^\(\d+\)\s*/, "").replace(/\s+-\s+YouTube( Music)?$/, "") : ""
  readonly property string cleanTitle: rawTitle.replace(/\s*[\(\[](official|lyrics?|audio|music video|video|visuali[sz]er|hd|4k)[^\)\]]*[\)\]]/ig, "").trim()
  readonly property string artist0: p ? String(p.trackArtist || "").trim() : ""
  readonly property bool splitTitle: artist0 === "" && cleanTitle.indexOf(" - ") > 0
  readonly property string artist: splitTitle ? cleanTitle.slice(0, cleanTitle.indexOf(" - ")) : artist0
  readonly property string title: splitTitle ? cleanTitle.slice(cleanTitle.indexOf(" - ") + 3) : cleanTitle
  readonly property string term: title === "" ? "" : (artist + " " + title).trim()
  readonly property bool wantLookup: live && p !== null && !(p.trackArtUrl) && term !== ""
  Component.onCompleted: if (wantLookup) ArtLookup.request(term)
  onWantLookupChanged: if (wantLookup) ArtLookup.request(term)
  onTermChanged: if (wantLookup) ArtLookup.request(term)
  readonly property string art: p && p.trackArtUrl ? String(p.trackArtUrl) : (ArtLookup.cache[term] || "")
  readonly property bool hasArt: art !== "" && bg.status === Image.Ready
  // Over art the text is always light (the scrim guarantees it); without art it follows the theme.
  readonly property color fg: hasArt ? Qt.rgba(1, 1, 1, 0.96) : Theme.text
  readonly property color fgMuted: hasArt ? Qt.rgba(1, 1, 1, 0.72) : Theme.textMuted

  implicitHeight: 140
  property alias visualizer: viz
  function fmt(sec) { sec = Math.max(0, Math.floor(sec)); return Math.floor(sec / 60) + ":" + ("0" + (sec % 60)).slice(-2) }

  // MPRIS doesn't push the position; ask once a second while playing and visible.
  Timer { interval: 1000; repeat: true; running: root.live && root.p !== null && root.p.isPlaying; onTriggered: root.p.positionChanged() }

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
  }

  Item {
    anchors.fill: parent; anchors.margins: Theme.s12
    // cover
    ClippingRectangle {
      id: cover
      width: 84; height: 84; radius: 14; color: Qt.rgba(1, 1, 1, root.hasArt ? 0.12 : 0.06)
      Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; source: root.art
        sourceSize.width: 256; sourceSize.height: 256; visible: status === Image.Ready }
      Icon { anchors.centerIn: parent; name: "music"; size: 28; color: root.fgMuted; visible: !root.hasArt }
    }
    Column {
      anchors.left: cover.right; anchors.leftMargin: Theme.s12; anchors.right: parent.right
      anchors.top: parent.top; spacing: 2
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
        text: root.title !== "" ? root.title : "Nothing playing"; color: root.fg; font.pixelSize: 15; font.bold: true }
      Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; visible: text !== ""
        text: root.artist !== "" ? root.artist : (root.p ? root.p.identity : ""); color: root.fgMuted; font.pixelSize: 12 }
    }
    // controls + visualizer share a row under the title
    Row {
      id: controls
      anchors.left: cover.right; anchors.leftMargin: Theme.s12
      y: cover.height - height; spacing: Theme.s8
      Repeater {
        model: [ { ic: "prev", act: 0 }, { ic: "play", act: 1 }, { ic: "next", act: 2 } ]
        delegate: Rectangle { required property var modelData
          width: modelData.act === 1 ? 40 : 32; height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: modelData.act === 1 ? Theme.accent : Qt.rgba(1, 1, 1, root.hasArt ? 0.16 : 0.08)
          Icon { anchors.centerIn: parent; size: modelData.act === 1 ? Theme.iconLg - 6 : Theme.iconSm
            name: modelData.act === 1 ? (root.p && root.p.isPlaying ? "pause" : "play") : modelData.ic
            color: modelData.act === 1 ? Theme.accentText : root.fg }
          MouseArea { anchors.fill: parent; enabled: root.p !== null; onClicked: {
            if (modelData.act === 0) root.p.previous(); else if (modelData.act === 2) root.p.next(); else root.p.togglePlaying() } } }
      }
    }
    Visualizer {
      id: viz
      anchors.left: controls.right; anchors.leftMargin: Theme.s12; anchors.right: parent.right
      y: cover.height - height; height: 30; bars: Math.max(8, Math.floor(width / 7))
      color: root.hasArt ? Qt.rgba(1, 1, 1, 0.9) : Theme.accent
      active: root.live && root.p !== null && root.p.isPlaying
    }
    // progress
    Column {
      anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; spacing: 3
      PillSlider { width: parent.width; thin: true; interactive: false
        value: root.p && root.p.length > 0 ? Math.min(1, root.p.position / root.p.length) : 0 }
      Item { width: parent.width; height: 12
        Text { textFormat: Text.PlainText; text: root.p ? root.fmt(root.p.position) : ""; color: root.fgMuted; font.pixelSize: 10 }
        Text { anchors.right: parent.right; textFormat: Text.PlainText; text: root.p ? root.fmt(root.p.length) : ""; color: root.fgMuted; font.pixelSize: 10 } }
    }
  }
}
