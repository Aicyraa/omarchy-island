pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 540
    useReserve: false
    hint: qsTr("↑/↓ move · ←/→ adjust · Enter toggle · Esc close")

    property int row: 0
    property int textSize: 12
    readonly property int lastRow: 6

    property bool hwLaptop: false
    property bool hwTouchpad: false
    property bool hwTouchscreen: false
    property bool laptopOff: false
    property bool mirrorOn: false
    property bool touchpadOff: false
    property bool touchscreenOff: false
    readonly property bool anyHw: hwLaptop || hwTouchpad || hwTouchscreen

    Component.onCompleted: {
        Brightness.refresh()
        Indicators.refresh()
    }

    function setText(n: int): void {
        textSize = Math.max(8, Math.min(24, n))
        Cmd.run(["omarchy-display-text-size", String(textSize)])
    }

    function rowVisible(r: int): bool {
        if (r === 3 || r === 4) return hwLaptop
        if (r === 5) return hwTouchpad
        if (r === 6) return hwTouchscreen
        return true
    }

    function step(d: int): void {
        let r = row + d
        while (r >= 0 && r <= lastRow && !rowVisible(r))
            r += d
        if (r >= 0 && r <= lastRow)
            row = r
    }

    function toggleHw(r: int): void {
        if (r === 3) Cmd.run(["omarchy-hyprland-monitor-internal", "toggle"])
        else if (r === 4) Cmd.run(["omarchy-hyprland-monitor-internal-mirror", "toggle"])
        else if (r === 5) Cmd.run(["omarchy-toggle-touchpad"])
        else if (r === 6) Cmd.run(["omarchy-toggle-touchscreen"])
        else return
        reprobe.restart()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            root.step(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.step(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            const d = event.key === Qt.Key_Right ? 1 : -1
            if (root.row === 0)
                Brightness.set(Brightness.level + d * 0.05)
            else if (root.row === 2)
                root.setText(root.textSize + d)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.row === 1)
                Indicators.toggleNightLight()
            else if (root.row >= 3)
                root.toggleHw(root.row)
            event.accepted = true
        }
    }

    Timer {
        id: reprobe
        interval: 800
        onTriggered: hwProbe.running = true
    }

    Process {
        id: hwProbe
        running: true
        command: [
            "bash", "-c",
            "h=\"$HOME/.local/state/omarchy/toggles/hypr\"; "
            + "omarchy-hw-laptop && echo laptop=1 || echo laptop=0; "
            + "[ -n \"$(omarchy-hw-touchpad 2>/dev/null)\" ] && echo touchpad=1 || echo touchpad=0; "
            + "[ -n \"$(omarchy-hw-touchscreen 2>/dev/null)\" ] && echo touchscreen=1 || echo touchscreen=0; "
            + "[ -f \"$h/internal-monitor-disable.lua\" ] && echo laptopOff=1 || echo laptopOff=0; "
            + "[ -f \"$h/internal-monitor-mirror.lua\" ] && echo mirror=1 || echo mirror=0; "
            + "[ -f \"$h/touchpad-disabled-name\" ] && echo touchpadOff=1 || echo touchpadOff=0; "
            + "[ -f \"$h/touchscreen-disabled-name\" ] && echo touchscreenOff=1 || echo touchscreenOff=0"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                String(text || "").split("\n").forEach(l => {
                    const i = l.indexOf("=")
                    if (i > 0)
                        v[l.slice(0, i)] = l.slice(i + 1) === "1"
                })
                root.hwLaptop = !!v.laptop
                root.hwTouchpad = !!v.touchpad
                root.hwTouchscreen = !!v.touchscreen
                root.laptopOff = !!v.laptopOff
                root.mirrorOn = !!v.mirror
                root.touchpadOff = !!v.touchpadOff
                root.touchscreenOff = !!v.touchscreenOff
            }
        }
    }

    Process {
        running: true
        command: ["omarchy-display-text-size"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /text size:\s*(\d+)/.exec(String(text || ""))
                if (m)
                    root.textSize = parseInt(m[1], 10)
            }
        }
    }

    // ── HEADER ──────────────────────────────────────────────────────────────────
    RowLayout {
        width: parent.width
        spacing: Tokens.space.sm

        Icon {
            icon: "sun"
            size: Tokens.size.iconXl
            tone: "accent"
            framed: true
        }

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Display & Hardware")
            detail: qsTr("Brightness, night light, text scale, and devices")
        }
    }

    // ── BRIGHTNESS CARD ─────────────────────────────────────────────────────────
    Card {
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: brightCol.implicitHeight + verticalPadding * 2

        FocusRing {
            active: root.row === 0
            ringRadius: Tokens.radius.md
        }

        ColumnLayout {
            id: brightCol
            width: parent.width
            spacing: Tokens.space.sm

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.sm

                Icon {
                    icon: "brightness"
                    size: Tokens.size.iconMd
                    tone: "accent"
                }

                TextLabel {
                    Layout.fillWidth: true
                    role: "subtitle"
                    font.weight: Font.Medium
                    text: qsTr("Brightness")
                }

                TextLabel {
                    role: "subtitle"
                    tabular: true
                    font.weight: Font.Medium
                    tone: Brightness.available ? "primary" : "muted"
                    text: Brightness.available ? Math.round(Brightness.level * 100) + "%" : qsTr("N/A")
                }
            }

            Slider {
                visible: Brightness.available
                Layout.fillWidth: true
                style: "pill"
                icon: "brightness"
                from: 0.01
                to: 1.0
                stepSize: 0.05
                value: Brightness.level
                showReadout: false
                accessibleLabel: qsTr("Display brightness")
                onMoved: v => {
                    root.row = 0
                    Brightness.set(v)
                }
            }

            TextLabel {
                visible: !Brightness.available
                role: "sm"
                tone: "muted"
                text: qsTr("No controllable backlight detected")
            }
        }
    }

    // ── NIGHT LIGHT CARD ────────────────────────────────────────────────────────
    Card {
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: nightRow.implicitHeight + verticalPadding * 2

        FocusRing {
            active: root.row === 1
            ringRadius: Tokens.radius.md
        }

        RowLayout {
            id: nightRow
            width: parent.width
            spacing: Tokens.space.md

            Icon {
                icon: "moon"
                size: Tokens.size.iconMd
                tone: Indicators.nightLight ? "accent" : "muted"
                framed: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xxs

                TextLabel {
                    Layout.fillWidth: true
                    role: "body"
                    font.weight: Font.Medium
                    text: qsTr("Night Light")
                }

                TextLabel {
                    Layout.fillWidth: true
                    role: "caption"
                    tone: Indicators.nightLight ? "accent" : "muted"
                    text: Indicators.nightLight ? qsTr("Warm tint active") : qsTr("Off")
                }
            }

            ToggleSwitch {
                checked: Indicators.nightLight
                accessibleLabel: qsTr("Toggle Night Light")
                onToggled: {
                    root.row = 1
                    Indicators.toggleNightLight()
                }
            }
        }
    }

    // ── TEXT SIZE STEPPER CARD ──────────────────────────────────────────────────
    Card {
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: textRow.implicitHeight + verticalPadding * 2

        FocusRing {
            active: root.row === 2
            ringRadius: Tokens.radius.md
        }

        RowLayout {
            id: textRow
            width: parent.width
            spacing: Tokens.space.md

            Icon {
                icon: "sliders-horizontal"
                size: Tokens.size.iconMd
                tone: "primary"
                framed: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xxs

                TextLabel {
                    Layout.fillWidth: true
                    role: "body"
                    font.weight: Font.Medium
                    text: qsTr("Text Size")
                }

                TextLabel {
                    Layout.fillWidth: true
                    role: "caption"
                    tone: "muted"
                    text: qsTr("System & terminal UI scale")
                }
            }

            Button {
                icon: "minus"
                variant: "secondary"
                size: "sm"
                accessibleLabel: qsTr("Decrease text size")
                onClicked: {
                    root.row = 2
                    root.setText(root.textSize - 1)
                }
            }

            TextLabel {
                Layout.preferredWidth: Tokens.px(48)
                horizontalAlignment: Text.AlignHCenter
                role: "body"
                tabular: true
                font.weight: Font.Medium
                text: root.textSize + " px"
            }

            Button {
                icon: "plus"
                variant: "secondary"
                size: "sm"
                accessibleLabel: qsTr("Increase text size")
                onClicked: {
                    root.row = 2
                    root.setText(root.textSize + 1)
                }
            }
        }
    }

    // ── HARDWARE TOGGLES ────────────────────────────────────────────────────────
    ColumnLayout {
        visible: root.anyHw
        width: parent.width
        spacing: Tokens.space.xs

        TextLabel {
            role: "sm"
            tone: "muted"
            font.weight: Font.Medium
            text: qsTr("Hardware")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Tokens.space.sm
            rowSpacing: Tokens.space.sm

            QuickTile {
                visible: root.hwLaptop
                Layout.fillWidth: true
                icon: "monitor"
                label: qsTr("Laptop Display")
                detail: root.laptopOff ? qsTr("Off") : qsTr("On")
                active: !root.laptopOff
                onToggled: {
                    root.row = 3
                    root.toggleHw(3)
                }
            }

            QuickTile {
                visible: root.hwLaptop
                Layout.fillWidth: true
                icon: "layers"
                label: qsTr("Mirror Display")
                detail: root.mirrorOn ? qsTr("On") : qsTr("Off")
                active: root.mirrorOn
                onToggled: {
                    root.row = 4
                    root.toggleHw(4)
                }
            }

            QuickTile {
                visible: root.hwTouchpad
                Layout.fillWidth: true
                icon: "sliders-horizontal"
                label: qsTr("Touchpad")
                detail: root.touchpadOff ? qsTr("Off") : qsTr("On")
                active: !root.touchpadOff
                onToggled: {
                    root.row = 5
                    root.toggleHw(5)
                }
            }

            QuickTile {
                visible: root.hwTouchscreen
                Layout.fillWidth: true
                icon: "sparkles"
                label: qsTr("Touchscreen")
                detail: root.touchscreenOff ? qsTr("Off") : qsTr("On")
                active: !root.touchscreenOff
                onToggled: {
                    root.row = 6
                    root.toggleHw(6)
                }
            }
        }
    }
}
