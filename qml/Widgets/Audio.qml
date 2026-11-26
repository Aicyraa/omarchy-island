pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 680
    useReserve: false
    scrollTarget: root.activeModel.length > 0 ? audioList : null
    hint: qsTr("Tab switch tab · ↑/↓ select · ←/→ volume · M mute · Esc close")

    property string currentTab: "outputs"
    property int sel: 0

    readonly property var appStreams: {
        const out = []
        const all = Pipewire.nodes ? Pipewire.nodes.values : []
        for (let i = 0; i < all.length; i++) {
            const n = all[i]
            if (n && n.isStream && n.audio)
                out.push(n)
        }
        return out
    }

    readonly property var activeModel: {
        if (currentTab === "inputs") return Audio.sources
        if (currentTab === "apps") return root.appStreams
        return Audio.sinks
    }

    onCurrentTabChanged: {
        sel = 0
        audioList.contentY = 0
    }

    function adjustMaster(delta: real): void {
        if (currentTab === "inputs")
            Audio.setMicVolume(Audio.micVolume + delta)
        else
            Audio.setVolume(Audio.volume + delta)
    }

    function toggleMasterMute(): void {
        if (currentTab === "inputs")
            Audio.toggleMicMute()
        else
            Audio.toggleMute()
    }

    Keys.onTabPressed: event => {
        tabStrip.stepTab(1)
        event.accepted = true
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            root.sel = Math.min(root.sel + 1, Math.max(0, root.activeModel.length - 1))
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.sel = Math.max(root.sel - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.adjustMaster(-0.05)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.adjustMaster(0.05)
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            root.toggleMasterMute()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const item = root.activeModel[root.sel]
            if (item) {
                if (root.currentTab === "outputs") Audio.setDefaultSink(item)
                else if (root.currentTab === "inputs") Audio.setDefaultSource(item)
            }
            event.accepted = true
        }
    }

    // ── HEADER ──────────────────────────────────────────────────────────────────
    DetailHeader {
        width: parent.width
        backable: false
        title: qsTr("Audio")
        icon: Audio.muted ? "volume-mute" : "volume"
        detail: Audio.hasSink ? "" : qsTr("No output device")
    }

    // ── MASTER OUTPUT & INPUT SLIDERS ───────────────────────────────────────────
    Card {
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: masterCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: masterCol
            width: parent.width
            spacing: Tokens.space.sm

            // Master Output
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                TextLabel {
                    Layout.preferredWidth: Tokens.px(56)
                    role: "sm"
                    tone: Audio.hasSink ? "secondary" : "disabled"
                    font.weight: Font.Medium
                    text: qsTr("Output")
                }

                Button {
                    icon: Audio.muted ? "volume-mute" : "volume"
                    variant: Audio.muted ? "danger" : "ghost"
                    size: "sm"
                    enabled: Audio.hasSink
                    accessibleLabel: qsTr("Toggle master output mute")
                    onClicked: Audio.toggleMute()
                }

                Slider {
                    Layout.fillWidth: true
                    style: "thin"
                    from: 0
                    to: 1.5
                    stepSize: 0.05
                    enabled: Audio.hasSink
                    value: Audio.volume
                    dimmed: !Audio.hasSink || Audio.muted
                    showReadout: false
                    accessibleLabel: qsTr("Master output volume")
                    onMoved: v => Audio.setVolume(v)
                }

                TextLabel {
                    Layout.preferredWidth: Tokens.px(48)
                    horizontalAlignment: Text.AlignRight
                    role: "sm"
                    tabular: true
                    font.weight: Font.Medium
                    tone: !Audio.hasSink ? "disabled"
                        : (Audio.muted ? "muted" : (Audio.volume > 1.005 ? "warning" : "primary"))
                    text: Audio.hasSink ? (Math.round(Audio.volume * 100) + "%") : qsTr("—")
                }
            }

            // Master Input
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                TextLabel {
                    Layout.preferredWidth: Tokens.px(56)
                    role: "sm"
                    tone: Audio.hasSource ? "secondary" : "disabled"
                    font.weight: Font.Medium
                    text: qsTr("Input")
                }

                Button {
                    icon: Audio.micMuted ? "mic-off" : "mic"
                    variant: Audio.micMuted ? "danger" : "ghost"
                    size: "sm"
                    enabled: Audio.hasSource
                    accessibleLabel: qsTr("Toggle master input mute")
                    onClicked: Audio.toggleMicMute()
                }

                Slider {
                    Layout.fillWidth: true
                    style: "thin"
                    from: 0
                    to: 1.5
                    stepSize: 0.05
                    enabled: Audio.hasSource
                    value: Audio.micVolume
                    dimmed: !Audio.hasSource || Audio.micMuted
                    showReadout: false
                    accessibleLabel: qsTr("Master input volume")
                    onMoved: v => Audio.setMicVolume(v)
                }

                TextLabel {
                    Layout.preferredWidth: Tokens.px(48)
                    horizontalAlignment: Text.AlignRight
                    role: "sm"
                    tabular: true
                    font.weight: Font.Medium
                    tone: !Audio.hasSource ? "disabled"
                        : (Audio.micMuted ? "muted" : (Audio.micVolume > 1.005 ? "warning" : "primary"))
                    text: Audio.hasSource ? (Math.round(Audio.micVolume * 100) + "%") : qsTr("—")
                }
            }
        }
    }

    // ── TABS ────────────────────────────────────────────────────────────────────
    TabStrip {
        id: tabStrip
        width: parent.width
        accessibleLabel: qsTr("Audio sections")
        current: root.currentTab
        tabs: [
            { id: "outputs", label: qsTr("Outputs") },
            { id: "inputs",  label: qsTr("Inputs") },
            { id: "apps",    label: qsTr("Apps") }
        ]
        onPicked: id => {
            root.currentTab = id
            audioListFade.restart()
        }
    }

    NumberAnimation {
        id: audioListFade
        target: audioListContainer
        property: "opacity"
        from: 0.25
        to: 1.0
        duration: (Tokens.reducedMotion || Tokens.gameMode) ? 0 : Math.round(120 * Tokens.motionScale)
        easing.type: Easing.OutCubic
    }

    // ── DEVICES / STREAMS LIST ──────────────────────────────────────────────────
    Surface {
        id: audioListContainer

        width: parent.width
        role: "card"
        horizontalPadding: Tokens.space.sm
        verticalPadding: Tokens.space.sm
        radius: Tokens.radius.md
        implicitHeight: root.activeModel.length > 0
            ? Math.min(root.currentTab === "apps" ? Tokens.px(104) * 2 : Tokens.px(52) * 4, audioList.contentHeight) + verticalPadding * 2
            : Tokens.px(96)

        EmptyState {
            visible: root.activeModel.length === 0
            anchors.centerIn: parent
            icon: root.currentTab === "inputs" ? "mic-off" : (root.currentTab === "apps" ? "music" : "volume-mute")
            title: root.currentTab === "inputs"
                ? qsTr("No input devices")
                : (root.currentTab === "apps" ? qsTr("No active app streams") : qsTr("No output devices"))
        }

        ListView {
            id: audioList

            visible: root.activeModel.length > 0
            anchors.fill: parent
            spacing: 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.activeModel

            delegate: Item {
                id: audioRow

                required property var modelData
                required property int index

                readonly property bool isApp: root.currentTab === "apps"
                readonly property bool isInput: root.currentTab === "inputs"
                readonly property var currentDev: isInput ? Audio.source : Audio.sink
                readonly property bool isActive: !isApp && currentDev !== null && currentDev !== undefined
                    && modelData.id === currentDev.id
                readonly property real streamVol: (isApp && modelData.audio) ? modelData.audio.volume : 0
                readonly property bool streamMuted: (isApp && modelData.audio) ? modelData.audio.muted : false

                PwObjectTracker {
                    objects: audioRow.isApp && audioRow.modelData ? [audioRow.modelData] : []
                }

                width: audioList.width
                implicitHeight: audioRow.isApp
                    ? (rowCol.implicitHeight + Tokens.space.sm * 2)
                    : Tokens.px(52)

                Rectangle {
                    visible: audioRow.index > 0
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Tokens.space.md
                    anchors.rightMargin: Tokens.space.md
                    height: Tokens.hairlineWidth
                    color: Tokens.color.hairline
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: audioRow.index > 0 ? Tokens.space.xxs : 0
                    anchors.bottomMargin: Tokens.space.xxs
                    radius: Tokens.radius.sm
                    color: (rowHover.hovered || root.sel === audioRow.index)
                        ? Tokens.veilHoverOf(Tokens.surfaceStyle)
                        : "transparent"

                    Behavior on color {
                        enabled: !Tokens.reducedMotion && !Tokens.gameMode
                        ColorAnimation { duration: Tokens.motion.fast }
                    }
                }

                FocusRing {
                    active: root.sel === audioRow.index
                    ringRadius: Tokens.radius.sm
                }

                ColumnLayout {
                    id: rowCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Tokens.px(14)
                    anchors.rightMargin: Tokens.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.space.sm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.md

                        Icon {
                            icon: audioRow.isInput
                                ? "mic"
                                : (audioRow.isApp ? "app-window"
                                    : (audioRow.modelData.name && audioRow.modelData.name.indexOf("bluez") >= 0
                                        ? "headphones" : "speaker"))
                            size: Tokens.size.iconMd
                            tone: audioRow.isActive ? "accent" : "primary"
                            framed: true
                        }

                        TextLabel {
                            Layout.fillWidth: true
                            role: "body"
                            font.weight: audioRow.isActive ? Font.Medium : Font.Normal
                            tone: audioRow.isActive ? "accent" : "primary"
                            text: Audio.label(audioRow.modelData)
                        }

                        Badge {
                            visible: !audioRow.isApp && audioRow.isActive
                            text: qsTr("Active")
                            tone: "accent"
                        }

                        Button {
                            visible: !audioRow.isApp && !audioRow.isActive
                            text: qsTr("Select")
                            variant: "secondary"
                            size: "sm"
                            accessibleLabel: qsTr("Select %1").arg(Audio.label(audioRow.modelData))
                            onClicked: {
                                root.sel = audioRow.index
                                if (audioRow.isInput) Audio.setDefaultSource(audioRow.modelData)
                                else Audio.setDefaultSink(audioRow.modelData)
                            }
                        }

                        Button {
                            visible: audioRow.isApp
                            icon: audioRow.streamMuted ? "volume-mute" : "volume"
                            variant: audioRow.streamMuted ? "danger" : "ghost"
                            size: "sm"
                            accessibleLabel: qsTr("Toggle mute for %1").arg(Audio.label(audioRow.modelData))
                            onClicked: {
                                if (audioRow.modelData.audio)
                                    audioRow.modelData.audio.muted = !audioRow.modelData.audio.muted
                            }
                        }
                    }

                    RowLayout {
                        visible: audioRow.isApp
                        Layout.fillWidth: true
                        spacing: Tokens.space.sm

                        Slider {
                            Layout.fillWidth: true
                            style: "pill"
                            from: 0
                            to: 1.5
                            stepSize: 0.05
                            value: audioRow.streamVol
                            dimmed: audioRow.streamMuted
                            showReadout: false
                            accessibleLabel: qsTr("Volume for %1").arg(Audio.label(audioRow.modelData))
                            onMoved: v => {
                                if (audioRow.modelData.audio) {
                                    audioRow.modelData.audio.muted = false
                                    audioRow.modelData.audio.volume = Audio.clamp(v)
                                }
                            }
                        }

                        TextLabel {
                            Layout.preferredWidth: Tokens.px(48)
                            horizontalAlignment: Text.AlignRight
                            role: "sm"
                            tabular: true
                            font.weight: Font.Medium
                            tone: audioRow.streamMuted ? "muted" : (audioRow.streamVol > 1.005 ? "warning" : "primary")
                            text: Math.round(audioRow.streamVol * 100) + "%"
                        }
                    }
                }

                HoverHandler {
                    id: rowHover
                    cursorShape: !audioRow.isApp ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                    enabled: !audioRow.isApp
                    onTapped: {
                        root.sel = audioRow.index
                        root.reveal(audioRow)
                        if (audioRow.isInput) Audio.setDefaultSource(audioRow.modelData)
                        else Audio.setDefaultSink(audioRow.modelData)
                    }
                }
            }
        }
    }
}
