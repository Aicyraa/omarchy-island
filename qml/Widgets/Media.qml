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

WidgetSurface {
    id: root

    preferredWidth: 440
    hPad: Tokens.space.lg
    vPad: Tokens.space.md
    compact: root.player === null
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

    Keys.onTabPressed: event => {
        if (root.players.length > 1) {
            IslandState.touch(true)
            root.selectedIndex = (root.clampedIndex + 1) % root.players.length
            event.accepted = true
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

    // Borderless media layout: large standalone left cover + right visualizer/controls/duration
    Item {
        id: heroCard

        visible: root.player !== null
        width: parent.width
        implicitHeight: heroCol.implicitHeight

        ColumnLayout {
            id: heroCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Tokens.space.xs

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.md

                // Left: Standalone large high-res album artwork (borderless)
                Item {
                    Layout.preferredWidth: Tokens.px(116)
                    Layout.preferredHeight: Tokens.px(116)
                    Layout.alignment: Qt.AlignVCenter

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.md
                        color: "transparent"
                        border.width: 0
                        border.color: "transparent"
                        visible: coverImg.status === Image.Ready

                        Image {
                            id: coverImg

                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                            sourceSize: Qt.size(256, 256)
                            source: root.artUrl
                        }
                    }

                    Vinyl {
                        anchors.fill: parent
                        visible: coverImg.status !== Image.Ready
                        spinning: root.player !== null && root.player.isPlaying && root.visible
                    }
                }

                // Right: Title + player dots, 48-bar visualizer, and start time / transport / end time
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Tokens.px(116)
                    spacing: Tokens.space.xs

                    // Top row: Track title/subtitle left + multi-player switcher dots top-right
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.sm

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Tokens.space.xxs

                            TextLabel {
                                Layout.fillWidth: true
                                role: "subtitle"
                                font.weight: Font.DemiBold
                                singleLine: true
                                elide: Text.ElideRight
                                text: root.trackTitle !== "" ? root.trackTitle : qsTr("Unknown track")
                                textFormat: Text.PlainText
                            }

                            TextLabel {
                                Layout.fillWidth: true
                                visible: root.trackSubtitle !== ""
                                role: "caption"
                                tone: "muted"
                                singleLine: true
                                elide: Text.ElideRight
                                text: root.trackSubtitle
                                textFormat: Text.PlainText
                            }
                        }

                        // Subtle multi-player switcher dots in top-right corner
                        Row {
                            visible: root.players.length > 1
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: Tokens.space.xxs
                            spacing: Tokens.space.xs

                            Repeater {
                                model: root.players.length

                                delegate: Rectangle {
                                    id: playerDot

                                    required property int index
                                    readonly property bool active: playerDot.index === root.clampedIndex

                                    width: active ? Tokens.px(16) : Tokens.px(6)
                                    height: Tokens.px(6)
                                    radius: Tokens.radius.pill
                                    color: active ? Tokens.color.accent : Tokens.color.textMuted
                                    opacity: active ? 1.0 : 0.45

                                    Behavior on width {
                                        enabled: !Tokens.reducedMotion && !Tokens.gameMode
                                        NumberAnimation { duration: Tokens.motion.fast; easing.type: Tokens.motion.easeOut }
                                    }

                                    TapHandler {
                                        onTapped: root.selectedIndex = playerDot.index
                                    }
                                }
                            }
                        }
                    }

                    // Middle row: Extended 48-bar audio visualizer with waveform seek
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: Tokens.px(36)

                        Visualizer {
                            anchors.fill: parent
                            bars: 48
                            mirror: true
                            gap: 2
                            maxBarW: Tokens.px(3)
                            active: root.playing && root.visible
                            progress: root.duration > 0
                                ? Math.max(0, Math.min(1, (root.player ? root.player.position : 0) / root.duration))
                                : -1
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.seekable
                            cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: mouse => {
                                if (root.seekable && width > 0)
                                    root.player.position = Math.max(0, Math.min(root.duration, (mouse.x / width) * root.duration))
                            }
                            onPositionChanged: mouse => {
                                if (pressed && root.seekable && width > 0)
                                    root.player.position = Math.max(0, Math.min(root.duration, (mouse.x / width) * root.duration))
                            }
                        }
                    }

                    // Bottom row: Start time (left) + prev/play-pause/next (center) + end time (right)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.sm

                        TextLabel {
                            visible: root.duration > 0
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            horizontalAlignment: Text.AlignLeft
                            role: "caption"
                            font.family: Tokens.type.monoFamily
                            tabular: true
                            tone: "muted"
                            text: root.fmtTime(root.player ? root.player.position : 0)
                            textFormat: Text.PlainText
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Tokens.space.xs

                            Button {
                                visible: root.playing
                                icon: "skip-back"
                                variant: "ghost"
                                shape: "circle"
                                size: "sm"
                                enabled: root.player !== null && root.player.canGoPrevious
                                accessibleLabel: qsTr("Previous track")
                                onClicked: {
                                    if (root.player)
                                        root.player.previous()
                                }
                            }

                            Button {
                                icon: root.playing ? "pause" : "play"
                                variant: "primary"
                                shape: "circle"
                                size: "md"
                                enabled: root.player !== null && (root.player.canPlay || root.player.canPause)
                                accessibleLabel: root.playing ? qsTr("Pause") : qsTr("Play")
                                onClicked: {
                                    if (root.player)
                                        root.player.togglePlaying()
                                }
                            }

                            Button {
                                visible: root.playing
                                icon: "skip-forward"
                                variant: "ghost"
                                shape: "circle"
                                size: "sm"
                                enabled: root.player !== null && root.player.canGoNext
                                accessibleLabel: qsTr("Next track")
                                onClicked: {
                                    if (root.player)
                                        root.player.next()
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        TextLabel {
                            visible: root.duration > 0
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            horizontalAlignment: Text.AlignRight
                            role: "caption"
                            font.family: Tokens.type.monoFamily
                            tabular: true
                            tone: "muted"
                            text: root.duration > 0 ? root.fmtTime(root.duration) : "--:--"
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }
    }
}
