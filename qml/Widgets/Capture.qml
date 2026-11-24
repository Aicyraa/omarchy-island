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

    preferredWidth: 480
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

    // Header
    RowLayout {
        width: parent.width
        spacing: Tokens.space.md

        Icon {
            icon: "camera"
            size: Tokens.size.iconLg
            tone: "accent"
            framed: true
        }

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Capture")
            detail: qsTr("Screenshots, screen recording, and quick tools")
        }
    }

    // Screenshots Card
    Card {
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.lg
        implicitHeight: screenshotCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: screenshotCol

            width: parent.width
            spacing: Tokens.space.md

            RowLayout {
                Layout.fillWidth: true

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

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                QuickTile {
                    Layout.fillWidth: true
                    icon: "crop"
                    label: qsTr("Region")
                    detail: qsTr("Smart")
                    onToggled: root.captureAfterClose(["omarchy-capture-screenshot"])
                }

                QuickTile {
                    Layout.fillWidth: true
                    icon: "maximize"
                    label: qsTr("Fullscreen")
                    onToggled: root.captureAfterClose(["omarchy-capture-screenshot", "--capture-fullscreen"])
                }

                QuickTile {
                    Layout.fillWidth: true
                    icon: "scissors"
                    label: qsTr("Annotate")
                    onToggled: root.captureAfterClose(["omarchy-capture-screenshot", "--editor"])
                }
            }
        }
    }

    // Screen Recording Card
    Card {
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.lg
        implicitHeight: recordCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: recordCol

            width: parent.width
            spacing: Tokens.space.md

            // Active recording danger banner
            Rectangle {
                visible: Indicators.recording
                Layout.fillWidth: true
                implicitHeight: activeRecRow.implicitHeight + Tokens.space.md * 2
                radius: Tokens.radius.sm
                color: Qt.rgba(Tokens.color.danger.r, Tokens.color.danger.g, Tokens.color.danger.b, 0.14)
                border.width: Tokens.hairlineWidth
                border.color: Qt.rgba(Tokens.color.danger.r, Tokens.color.danger.g, Tokens.color.danger.b, 0.35)

                RowLayout {
                    id: activeRecRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space.md
                    anchors.rightMargin: Tokens.space.md
                    spacing: Tokens.space.sm

                    StatusDot {
                        tone: "danger"
                        pulse: true
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "body"
                        font.weight: Font.Medium
                        tone: "danger"
                        text: qsTr("Recording in progress")
                    }

                    Button {
                        variant: "danger"
                        icon: "square"
                        text: qsTr("Stop Recording")
                        onClicked: {
                            Cmd.run(["omarchy-capture-screenrecording", "--stop-recording"])
                            Indicators.refresh()
                        }
                    }
                }
            }

            // Idle recording controls
            ColumnLayout {
                visible: !Indicators.recording
                Layout.fillWidth: true
                spacing: Tokens.space.md

                TextLabel {
                    Layout.fillWidth: true
                    role: "sm"
                    font.weight: Font.Medium
                    tone: "secondary"
                    text: qsTr("Screen Recording")
                }

                SegmentedControl {
                    Layout.fillWidth: true
                    stretch: true
                    options: [
                        { id: "none", label: qsTr("Silent") },
                        { id: "desktop", label: qsTr("Desktop") },
                        { id: "mic", label: qsTr("Desktop + Mic") }
                    ]
                    current: root.audioSource
                    accessibleLabel: qsTr("Recording audio source")
                    onSelected: id => root.audioSource = id
                }

                Button {
                    Layout.fillWidth: true
                    variant: "primary"
                    icon: "video"
                    text: qsTr("Start Recording")
                    onClicked: root.startRecording()
                }
            }
        }
    }

    // Quick Tools row
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        QuickTile {
            Layout.fillWidth: true
            icon: "scan-text"
            label: qsTr("OCR Text")
            onToggled: root.runToolAfterClose("omarchy-capture-text")
        }

        QuickTile {
            Layout.fillWidth: true
            icon: "qr-code"
            label: qsTr("QR Scan")
            onToggled: root.runToolAfterClose("omarchy-capture-qr")
        }

        QuickTile {
            Layout.fillWidth: true
            icon: "pipette"
            label: qsTr("Color Picker")
            onToggled: root.runToolAfterClose("(pkill hyprpicker || hyprpicker -a)")
        }
    }
}
