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

    preferredWidth: 640
    useReserve: false
    scrollTarget: audioList
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
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        Icon {
            icon: Audio.muted ? "volume-mute" : "volume"
            size: Tokens.size.iconXl
            tone: Audio.muted ? "muted" : "accent"
            framed: true
        }

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Audio")
            detail: Audio.sink ? Audio.label(Audio.sink) : qsTr("No output device")
        }

        Button {
            icon: Audio.muted ? "volume-mute" : "volume"
            text: Audio.muted ? qsTr("Muted") : qsTr("Mute")
            variant: Audio.muted ? "danger" : "secondary"
            size: "sm"
            accessibleLabel: qsTr("Toggle master mute")
            onClicked: Audio.toggleMute()
        }
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
                spacing: Tokens.space.md

                TextLabel {
                    Layout.preferredWidth: Tokens.px(56)
                    role: "sm"
                    tone: "secondary"
                    font.weight: Font.Medium
                    text: qsTr("Output")
                }

                Slider {
                    Layout.fillWidth: true
                    style: "pill"
                    from: 0
                    to: 1.5
                    stepSize: 0.05
                    value: Audio.volume
                    icon: Audio.muted ? "volume-mute" : "volume"
                    dimmed: Audio.muted
                    showReadout: false
                    accessibleLabel: qsTr("Master output volume")
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }

                TextLabel {
                    Layout.preferredWidth: Tokens.px(48)
                    horizontalAlignment: Text.AlignRight
                    role: "sm"
                    tabular: true
                    font.weight: Font.Medium
                    tone: Audio.muted ? "muted" : (Audio.volume > 1.005 ? "warning" : "primary")
                    text: Math.round(Audio.volume * 100) + "%"
                }
            }

            // Master Input
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.md

                TextLabel {
                    Layout.preferredWidth: Tokens.px(56)
                    role: "sm"
                    tone: "secondary"
                    font.weight: Font.Medium
                    text: qsTr("Input")
                }

                Slider {
                    Layout.fillWidth: true
                    style: "pill"
                    from: 0
                    to: 1.5
                    stepSize: 0.05
                    value: Audio.micVolume
                    icon: Audio.micMuted ? "mic-off" : "mic"
                    dimmed: Audio.micMuted
                    showReadout: false
                    accessibleLabel: qsTr("Master input volume")
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                }

                TextLabel {
                    Layout.preferredWidth: Tokens.px(48)
                    horizontalAlignment: Text.AlignRight
                    role: "sm"
                    tabular: true
                    font.weight: Font.Medium
                    tone: Audio.micMuted ? "muted" : (Audio.micVolume > 1.005 ? "warning" : "primary")
                    text: Math.round(Audio.micVolume * 100) + "%"
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
        onPicked: id => root.currentTab = id
    }

    // ── DEVICES / STREAMS LIST ──────────────────────────────────────────────────
    ListView {
        id: audioList

        width: parent.width
        height: root.activeModel.length > 0 ? Math.min(contentHeight, Tokens.px(210)) : Tokens.px(120)
        spacing: Tokens.space.xs
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.activeModel

        EmptyState {
            visible: root.activeModel.length === 0
            anchors.centerIn: parent
            icon: root.currentTab === "inputs" ? "mic-off" : (root.currentTab === "apps" ? "music" : "volume-mute")
            title: root.currentTab === "inputs"
                ? qsTr("No input devices")
                : (root.currentTab === "apps" ? qsTr("No active app streams") : qsTr("No output devices"))
        }

        delegate: Card {
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
            horizontalPadding: Tokens.space.lg
            verticalPadding: Tokens.space.md
            hovered: rowHover.hovered || root.sel === audioRow.index
            implicitHeight: rowCol.implicitHeight + verticalPadding * 2

            FocusRing {
                active: root.sel === audioRow.index
                ringRadius: audioRow.radius
            }

            ColumnLayout {
                id: rowCol
                width: parent.width
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
                        visible: audioRow.isActive
                        text: qsTr("In use")
                        tone: "accent"
                    }

                    Button {
                        visible: !audioRow.isApp
                        text: audioRow.isActive ? qsTr("Active") : qsTr("Select")
                        variant: audioRow.isActive ? "primary" : "secondary"
                        size: "sm"
                        enabled: !audioRow.isActive
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
                    spacing: Tokens.space.md

                    Slider {
                        Layout.fillWidth: true
                        style: "pill"
                        from: 0
                        to: 1.5
                        stepSize: 0.05
                        value: audioRow.streamVol
                        icon: audioRow.streamMuted ? "volume-mute" : "volume"
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
                        Layout.preferredWidth: Tokens.px(44)
                        horizontalAlignment: Text.AlignRight
                        role: "sm"
                        tabular: true
                        tone: audioRow.streamMuted ? "muted" : "primary"
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
