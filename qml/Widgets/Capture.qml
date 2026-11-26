pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 540
    hint: qsTr("1-3 screenshot · R record · Esc close")

    property string delayId: "0"
    property string audioSource: "none"

    Component.onCompleted: Indicators.refresh()

    function shellQuote(arg: string): string {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function captureAfterClose(cmdArgs: var): void {
        const delaySec = parseInt(root.delayId, 10) || 0
        const waitSec = delaySec > 0 ? delaySec : 0.25
        const cmdStr = cmdArgs.map(shellQuote).join(" ")
        IslandState.closeWidget("capture")
        Quickshell.execDetached(["bash", "-c", "sleep " + waitSec + " && " + cmdStr])
    }

    function runToolAfterClose(shellCmd: string): void {
        IslandState.closeWidget("capture")
        Quickshell.execDetached(["bash", "-c", "sleep 0.25 && " + shellCmd])
    }

    function startRecording(): void {
        const args = ["omarchy-capture-screenrecording"]
        if (root.audioSource === "desktop" || root.audioSource === "mic")
            args.push("--with-desktop-audio")
        if (root.audioSource === "mic")
            args.push("--with-microphone-audio")
        IslandState.closeWidget("capture")
        Quickshell.execDetached(args)
    }

    function toggleRecording(): void {
        if (Indicators.recording) {
            Cmd.run(["omarchy-capture-screenrecording", "--stop-recording"])
            Indicators.refresh()
        } else {
            startRecording()
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_1) {
            IslandState.touch(true)
            root.captureAfterClose(["omarchy-capture-screenshot"])
            event.accepted = true
        } else if (event.key === Qt.Key_2) {
            IslandState.touch(true)
            root.captureAfterClose(["omarchy-capture-screenshot", "--capture-fullscreen"])
            event.accepted = true
        } else if (event.key === Qt.Key_3) {
            IslandState.touch(true)
            root.captureAfterClose(["omarchy-capture-screenshot", "--editor"])
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            IslandState.touch(true)
            root.toggleRecording()
            event.accepted = true
        }
    }

    // Vertical airy action tile
    component CaptureTile: Rectangle {
        id: tile

        property string icon: ""
        property string label: ""
        property string shortcut: ""
        property string iconTone: "accent"

        signal triggered()

        implicitWidth: Tokens.px(156)
        implicitHeight: Math.max(Tokens.px(76), tileCol.implicitHeight + Tokens.space.lg * 2)
        radius: Tokens.radius.md
        activeFocusOnTab: true
        color: tileHover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : Tokens.veilOf(Tokens.surfaceStyle)
        border.width: Tokens.hairlineWidth
        border.color: tileHover.hovered ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

        Behavior on color {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            ColorAnimation { duration: Tokens.motion.fast }
        }
        Behavior on border.color {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            ColorAnimation { duration: Tokens.motion.fast }
        }

        Accessible.role: Accessible.Button
        Accessible.name: tile.label

        FocusRing {
            active: tile.activeFocus
            ringRadius: tile.radius
        }

        ColumnLayout {
            id: tileCol

            anchors.fill: parent
            anchors.margins: Tokens.space.lg
            spacing: Tokens.space.xs

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xs

                Icon {
                    icon: tile.icon
                    size: Tokens.size.iconMd
                    tone: tile.iconTone
                    framed: true
                }

                Item { Layout.fillWidth: true }

                Keycap {
                    visible: tile.shortcut !== ""
                    size: "sm"
                    text: tile.shortcut
                }
            }

            Item { Layout.fillHeight: true }

            TextLabel {
                Layout.fillWidth: true
                role: "body"
                font.weight: Font.Medium
                tone: "primary"
                text: tile.label
            }
        }

        HoverHandler {
            id: tileHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                Tokens.keyboardNavigation = false
                tile.triggered()
            }
        }

        Keys.onSpacePressed: tile.triggered()
        Keys.onReturnPressed: tile.triggered()
    }

    // Header
    DetailHeader {
        width: parent.width
        title: qsTr("Capture")
        icon: "camera"
        backable: false
    }

    // Screenshots section (no outer Card — aligns edge-to-edge with Quick Tools)
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        TextLabel {
            Layout.fillWidth: true
            role: "sm"
            font.weight: Font.Medium
            tone: "secondary"
            text: qsTr("Screenshots")
        }

        SegmentedControl {
            options: [
                { id: "0", label: "0s" },
                { id: "3", label: "3s" },
                { id: "5", label: "5s" }
            ]
            current: root.delayId
            accessibleLabel: qsTr("Screenshot delay")
            onSelected: id => root.delayId = id
        }
    }

    GridLayout {
        width: parent.width
        columns: 3
        columnSpacing: Tokens.space.sm
        rowSpacing: Tokens.space.sm

        CaptureTile {
            Layout.fillWidth: true
            icon: "crop"
            label: qsTr("Region")
            shortcut: "1"
            onTriggered: root.captureAfterClose(["omarchy-capture-screenshot"])
        }

        CaptureTile {
            Layout.fillWidth: true
            icon: "maximize"
            label: qsTr("Fullscreen")
            shortcut: "2"
            onTriggered: root.captureAfterClose(["omarchy-capture-screenshot", "--capture-fullscreen"])
        }

        CaptureTile {
            Layout.fillWidth: true
            icon: "scissors"
            label: qsTr("Annotate")
            shortcut: "3"
            onTriggered: root.captureAfterClose(["omarchy-capture-screenshot", "--editor"])
        }
    }

    // Compact 1-row Screen Recording bar
    Card {
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: recRow.implicitHeight + verticalPadding * 2

        RowLayout {
            id: recRow

            width: parent.width
            spacing: Tokens.space.md

            Icon {
                icon: "video"
                size: Tokens.size.iconMd
                tone: Indicators.recording ? "danger" : "accent"
                framed: true
            }

            TextLabel {
                visible: !Indicators.recording
                role: "body"
                font.weight: Font.Medium
                text: qsTr("Screen Recording")
            }

            SegmentedControl {
                visible: !Indicators.recording
                Layout.fillWidth: true
                stretch: true
                options: [
                    { id: "none", label: qsTr("Silent") },
                    { id: "desktop", label: qsTr("Audio") },
                    { id: "mic", label: qsTr("Mic") }
                ]
                current: root.audioSource
                accessibleLabel: qsTr("Recording audio source")
                onSelected: id => root.audioSource = id
            }

            StatusDot {
                visible: Indicators.recording
                tone: "danger"
                pulse: true
            }

            TextLabel {
                visible: Indicators.recording
                Layout.fillWidth: true
                role: "body"
                font.weight: Font.Medium
                tone: "danger"
                text: qsTr("Recording active")
            }

            Button {
                size: "sm"
                variant: Indicators.recording ? "danger" : "primary"
                icon: Indicators.recording ? "square" : "video"
                text: Indicators.recording ? qsTr("Stop") : qsTr("Start")
                accessibleLabel: Indicators.recording ? qsTr("Stop screen recording") : qsTr("Start screen recording")
                onClicked: root.toggleRecording()
            }
        }
    }

    // Quick Tools 3-column grid
    GridLayout {
        width: parent.width
        columns: 3
        columnSpacing: Tokens.space.sm
        rowSpacing: Tokens.space.sm

        CaptureTile {
            Layout.fillWidth: true
            icon: "scan-text"
            iconTone: "secondary"
            label: qsTr("OCR Text")
            onTriggered: root.runToolAfterClose("omarchy-capture-text")
        }

        CaptureTile {
            Layout.fillWidth: true
            icon: "qr-code"
            iconTone: "secondary"
            label: qsTr("QR Scan")
            onTriggered: root.runToolAfterClose("omarchy-capture-qr")
        }

        CaptureTile {
            Layout.fillWidth: true
            icon: "pipette"
            iconTone: "secondary"
            label: qsTr("Color Picker")
            onTriggered: root.runToolAfterClose("(pkill hyprpicker || hyprpicker -a)")
        }
    }
}
