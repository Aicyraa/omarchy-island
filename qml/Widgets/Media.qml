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

    preferredWidth: 480
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
        if (parts.length === 0 && player && player.identity)
            parts.push(String(player.identity))
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

    // Multi-player switcher pills
    Row {
        visible: root.players.length > 1
        width: parent.width
        spacing: Tokens.space.xs

        Repeater {
            model: root.players

            Button {
                required property int index
                required property var modelData

                size: "sm"
                shape: "pill"
                variant: "secondary"
                active: index === root.clampedIndex
                text: modelData.identity || qsTr("Player %1").arg(index + 1)
                onClicked: root.selectedIndex = index
            }
        }
    }

    // Empty state when no MPRIS player is active
    EmptyState {
        visible: root.player === null
        width: parent.width
        icon: "music"
        title: qsTr("Nothing playing")
        description: qsTr("Start audio or media in any app")
    }

    // Active player hero card
    Card {
        visible: root.player !== null
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.lg
        implicitHeight: heroCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: heroCol

            width: parent.width
            spacing: Tokens.space.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.lg

                // 96x96 rounded album art with Vinyl spinning fallback
                Item {
                    Layout.preferredWidth: Tokens.px(96)
                    Layout.preferredHeight: Tokens.px(96)
                    Layout.alignment: Qt.AlignTop

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
                            sourceSize: Qt.size(Tokens.px(192), Tokens.px(192))
                            source: root.artUrl
                        }
                    }

                    Vinyl {
                        anchors.fill: parent
                        visible: coverImg.status !== Image.Ready
                        spinning: root.player !== null && root.player.isPlaying && root.visible
                    }
                }

                // Track metadata + transport controls
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Tokens.space.xs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "title"
                        font.weight: Font.Medium
                        text: root.trackTitle !== "" ? root.trackTitle : qsTr("Unknown track")
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        visible: root.trackSubtitle !== ""
                        role: "sm"
                        tone: "muted"
                        text: root.trackSubtitle
                    }

                    RowLayout {
                        Layout.topMargin: Tokens.space.xs
                        spacing: Tokens.space.xs

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
                    }
                }
            }

            // Live mirrored visualizer
            Visualizer {
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.px(28)
                active: root.player !== null && root.player.isPlaying && root.visible
                mirror: true
                progress: root.hasLength ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : -1
            }

            // Scrubbing slider + tabular elapsed & total time
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xxs

                Slider {
                    Layout.fillWidth: true
                    style: "thin"
                    showReadout: false
                    from: 0
                    to: root.hasLength ? root.player.length : 1
                    stepSize: 1
                    value: root.hasLength ? Math.min(root.player.length, Math.max(0, root.player.position)) : 0
                    enabled: root.seekable
                    accessibleLabel: qsTr("Playback position")
                    onMoved: val => {
                        if (root.seekable)
                            root.player.position = val
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    TextLabel {
                        role: "mono"
                        tabular: true
                        tone: "muted"
                        text: root.fmtTime(root.player ? root.player.position : 0)
                    }

                    Item { Layout.fillWidth: true }

                    TextLabel {
                        role: "mono"
                        tabular: true
                        tone: "muted"
                        text: root.hasLength ? root.fmtTime(root.player.length) : "--:--"
                    }
                }
            }
        }
    }

    // Bottom master output volume row + Mixer button
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        VolumeIcon {
            Layout.alignment: Qt.AlignVCenter
            level: Audio.volume
            muted: Audio.muted
            size: Tokens.size.iconMd
        }

        Slider {
            Layout.fillWidth: true
            style: "pill"
            from: 0
            to: 1.5
            stepSize: 0.05
            showReadout: false
            dimmed: Audio.muted || !Audio.hasSink
            enabled: Audio.hasSink
            value: Audio.volume
            accessibleLabel: qsTr("Master output volume")
            onMoved: val => Audio.setVolume(val)
        }

        TextLabel {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Tokens.px(38)
            horizontalAlignment: Text.AlignRight
            role: "mono"
            tabular: true
            tone: Audio.muted ? "muted" : "secondary"
            text: Math.round(Audio.volume * 100) + "%"
        }

        Button {
            text: qsTr("Mixer")
            icon: "sliders-horizontal"
            variant: "ghost"
            size: "sm"
            accessibleLabel: qsTr("Open audio mixer")
            onClicked: IslandState.openWidget("audio")
        }
    }
}
