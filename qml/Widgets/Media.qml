pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../Core"
import "../Core/Visuals"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 540
    hint: qsTr("Space play/pause · ←/→ seek · ↑/↓ volume · Esc close")

    property int selectedIndex: 0
    property int rev: 0

    readonly property var players: Mpris.players.values
    readonly property int clampedIndex: players.length > 0
        ? Math.max(0, Math.min(selectedIndex, players.length - 1))
        : 0
    readonly property var player: players.length > 0 ? players[clampedIndex] : null

    readonly property string rawTitle: {
        if (root.rev < 0)
            return ""
        return player ? String(player.trackTitle || "")
            .replace(/^\(\d+\)\s*/, "")
            .replace(/\s+-\s+YouTube( Music)?$/, "") : ""
    }
    readonly property string cleanTitle: rawTitle
        .replace(/\|.*$/, "")
        .replace(/\s*[\(\[][^\)\]]*[\)\]]/g, "")
        .replace(/\s+/g, " ")
        .trim()
    readonly property string rawArtist: {
        if (root.rev < 0)
            return ""
        return player ? String(player.trackArtist || "").trim() : ""
    }
    readonly property string rawAlbum: {
        if (root.rev < 0)
            return ""
        return player ? String(player.trackAlbum || "").trim() : ""
    }
    readonly property bool splitTitle: rawArtist === "" && cleanTitle.indexOf(" - ") > 0
    readonly property string trackArtist: splitTitle
        ? cleanTitle.slice(0, cleanTitle.indexOf(" - "))
        : rawArtist
    readonly property string trackTitle: splitTitle
        ? cleanTitle.slice(cleanTitle.indexOf(" - ") + 3)
        : cleanTitle
    readonly property string trackSubtitle: {
        const parts = []
        if (trackArtist !== "")
            parts.push(trackArtist)
        if (rawAlbum !== "")
            parts.push(rawAlbum)
        return parts.join(" · ")
    }

    readonly property string lookupTerm: trackTitle === "" ? "" : (trackArtist + " " + trackTitle).trim()
    readonly property bool wantLookup: visible && player !== null && !(player.trackArtUrl) && lookupTerm !== ""

    onWantLookupChanged: if (wantLookup) ArtLookup.request(lookupTerm)
    onLookupTermChanged: if (wantLookup) ArtLookup.request(lookupTerm)
    Component.onCompleted: if (wantLookup) ArtLookup.request(lookupTerm)

    readonly property string artUrl: {
        if (root.rev < 0)
            return ""
        if (player && player.trackArtUrl)
            return String(player.trackArtUrl)
        return ArtLookup.cache[lookupTerm] || ""
    }

    readonly property bool hasLength: player !== null && player.lengthSupported && player.length > 0
    readonly property bool playing: player !== null && player.isPlaying
    readonly property real duration: hasLength ? player.length : 0
    readonly property bool seekable: hasLength && player.canSeek

    function fmtTime(sec: real): string {
        const s = Math.max(0, Math.floor(sec))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" + r : "" + r)
    }

    function seekBy(deltaSec: real): void {
        if (!seekable)
            return
        player.position = Math.max(0, Math.min(player.length, player.position + deltaSec))
    }

    function cycleLoop(): void {
        if (!player || !player.loopSupported)
            return
        if (player.loopState === MprisLoopState.None)
            player.loopState = MprisLoopState.Playlist
        else if (player.loopState === MprisLoopState.Playlist)
            player.loopState = MprisLoopState.Track
        else
            player.loopState = MprisLoopState.None
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackChanged() { root.rev++ }
        function onPostTrackChanged() { root.rev++ }
        function onMetadataChanged() { root.rev++ }
        function onTrackTitleChanged() { root.rev++ }
        function onTrackArtistChanged() { root.rev++ }
        function onTrackAlbumChanged() { root.rev++ }
        function onTrackArtUrlChanged() { root.rev++ }
        function onIsPlayingChanged() { root.rev++ }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying
        onTriggered: {
            if (root.player)
                root.player.positionChanged()
        }
    }

    Keys.onSpacePressed: event => {
        IslandState.touch(true)
        if (root.player)
            root.player.togglePlaying()
        event.accepted = true
    }
    Keys.onLeftPressed: event => {
        IslandState.touch(true)
        root.seekBy(-5)
        event.accepted = true
    }
    Keys.onRightPressed: event => {
        IslandState.touch(true)
        root.seekBy(5)
        event.accepted = true
    }
    Keys.onUpPressed: event => {
        IslandState.touch(true)
        Audio.setVolume(Audio.volume + 0.05)
        event.accepted = true
    }
    Keys.onDownPressed: event => {
        IslandState.touch(true)
        Audio.setVolume(Audio.volume - 0.05)
        event.accepted = true
    }

    // Empty state when no MPRIS player is active
    EmptyState {
        visible: root.player === null
        width: parent.width
        icon: "music"
        title: qsTr("Nothing playing")
        description: qsTr("Start music or video to control playback here")
    }

    // Multi-player switcher strip
    TabStrip {
        visible: root.player !== null && root.players.length > 1
        width: parent.width
        stretch: true
        accessibleLabel: qsTr("Active media player")
        tabs: root.players.map(function (p, i) {
            return { id: String(i), label: p.identity || qsTr("Player %1").arg(i + 1) }
        })
        current: String(root.clampedIndex)
        onPicked: function (id) { root.selectedIndex = parseInt(id, 10) || 0 }
    }

    // Quiet single-line source pill when only one player is active
    Rectangle {
        visible: root.player !== null && root.players.length === 1 && (root.player.identity || "") !== ""
        implicitWidth: sourcePillRow.implicitWidth + Tokens.space.md * 2
        implicitHeight: Tokens.px(24)
        radius: Tokens.radius.pill
        color: Tokens.veilOf(Tokens.surfaceStyle)
        border.width: Tokens.hairlineWidth
        border.color: Tokens.veilBorderOf(Tokens.surfaceStyle)

        RowLayout {
            id: sourcePillRow

            anchors.centerIn: parent
            spacing: Tokens.space.xs

            Icon {
                icon: "music"
                size: Tokens.size.iconXs
                tone: "muted"
            }

            TextLabel {
                role: "caption"
                tone: "muted"
                text: root.player ? (root.player.identity || "") : ""
            }
        }
    }

    // Active player hero card
    Card {
        id: heroCard

        visible: root.player !== null
        width: parent.width
        horizontalPadding: 0
        verticalPadding: 0
        implicitHeight: heroCol.implicitHeight + Tokens.space.lg * 2

        // Subtle tinted album-art ambient backdrop scrim
        ClippingRectangle {
            anchors.fill: parent
            radius: heroCard.radius
            color: "transparent"
            visible: coverImg.status === Image.Ready

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(Tokens.px(64), Tokens.px(64))
                source: root.artUrl
                opacity: 0.14
            }
        }

        ColumnLayout {
            id: heroCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space.lg
            spacing: Tokens.space.md

            // Top row: 84x84 cover art + 2-line title/subtitle + compact non-progress Visualizer
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.lg

                Item {
                    Layout.preferredWidth: Tokens.px(84)
                    Layout.preferredHeight: Tokens.px(84)
                    Layout.alignment: Qt.AlignVCenter

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.md
                        color: Tokens.veilOf(Tokens.surfaceStyle)
                        visible: coverImg.status === Image.Ready

                        Image {
                            id: coverImg

                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(Tokens.px(168), Tokens.px(168))
                            source: root.artUrl
                        }
                    }

                    Vinyl {
                        anchors.fill: parent
                        visible: coverImg.status !== Image.Ready
                        spinning: root.player !== null && root.player.isPlaying && root.visible
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Tokens.space.xs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "title"
                        font.weight: Font.Medium
                        singleLine: false
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: root.trackTitle !== "" ? root.trackTitle : qsTr("Unknown track")
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        visible: root.trackSubtitle !== ""
                        role: "sm"
                        tone: "muted"
                        text: root.trackSubtitle
                    }
                }

                Visualizer {
                    visible: root.playing
                    Layout.preferredWidth: Tokens.px(64)
                    Layout.preferredHeight: Tokens.px(28)
                    Layout.alignment: Qt.AlignVCenter
                    bars: 12
                    mirror: true
                    progress: -1
                    active: root.playing && root.visible
                }
            }

            // Full-width centered 5-control transport bar
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.md

                Item { Layout.fillWidth: true }

                Button {
                    icon: "shuffle"
                    variant: "ghost"
                    shape: "circle"
                    size: "sm"
                    active: root.player !== null && root.player.shuffle
                    enabled: root.player !== null && root.player.shuffleSupported
                    accessibleLabel: qsTr("Shuffle")
                    onClicked: {
                        if (root.player && root.player.shuffleSupported)
                            root.player.shuffle = !root.player.shuffle
                    }
                }

                Button {
                    icon: "skip-back"
                    variant: "ghost"
                    shape: "circle"
                    size: "md"
                    enabled: root.player !== null && root.player.canGoPrevious
                    accessibleLabel: qsTr("Previous track")
                    onClicked: {
                        if (root.player)
                            root.player.previous()
                    }
                }

                Button {
                    icon: root.player !== null && root.player.isPlaying ? "pause" : "play"
                    variant: "primary"
                    shape: "circle"
                    size: "lg"
                    enabled: root.player !== null && (root.player.canPlay || root.player.canPause)
                    accessibleLabel: root.player !== null && root.player.isPlaying ? qsTr("Pause") : qsTr("Play")
                    onClicked: {
                        if (root.player)
                            root.player.togglePlaying()
                    }
                }

                Button {
                    icon: "skip-forward"
                    variant: "ghost"
                    shape: "circle"
                    size: "md"
                    enabled: root.player !== null && root.player.canGoNext
                    accessibleLabel: qsTr("Next track")
                    onClicked: {
                        if (root.player)
                            root.player.next()
                    }
                }

                Button {
                    icon: "repeat"
                    variant: "ghost"
                    shape: "circle"
                    size: "sm"
                    active: root.player !== null && root.player.loopState !== MprisLoopState.None
                    enabled: root.player !== null && root.player.loopSupported
                    accessibleLabel: qsTr("Repeat")
                    onClicked: root.cycleLoop()
                }

                Item { Layout.fillWidth: true }
            }

            // Thin scrubbing slider with 48 px tabular elapsed/total timestamps
            RowLayout {
                visible: root.duration > 0
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                TextLabel {
                    Layout.preferredWidth: Tokens.px(48)
                    horizontalAlignment: Text.AlignLeft
                    role: "mono"
                    tabular: true
                    tone: "muted"
                    text: root.fmtTime(root.player ? root.player.position : 0)
                }

                Slider {
                    Layout.fillWidth: true
                    style: "thin"
                    showReadout: false
                    from: 0
                    to: root.duration > 0 ? root.duration : 1
                    stepSize: 1
                    value: root.duration > 0 ? Math.min(root.duration, Math.max(0, root.player.position)) : 0
                    enabled: root.seekable
                    accessibleLabel: qsTr("Playback position")
                    onMoved: val => {
                        if (root.seekable)
                            root.player.position = val
                    }
                }

                TextLabel {
                    Layout.preferredWidth: Tokens.px(48)
                    horizontalAlignment: Text.AlignRight
                    role: "mono"
                    tabular: true
                    tone: "muted"
                    text: root.duration > 0 ? root.fmtTime(root.duration) : "--:--"
                }
            }
        }
    }
}
