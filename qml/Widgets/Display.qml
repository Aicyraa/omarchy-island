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

    preferredWidth: 560
    useReserve: false
    hint: qsTr("↑/↓ move · ←/→ adjust · Enter toggle · Esc close")

    property int row: Brightness.available ? 0 : 1
    property int textSize: 12
    readonly property int lastRow: 6

    property bool hwLaptop: false
    property bool hwTouchpad: false
    property bool hwTouchscreen: false
    property bool laptopOff: false
    property bool mirrorOn: false
    property bool touchpadOff: false
    property bool touchscreenOff: false
    readonly property int visibleHwCount: (hwLaptop ? 2 : 0) + (hwTouchpad ? 1 : 0) + (hwTouchscreen ? 1 : 0)
    readonly property bool anyHw: visibleHwCount > 0

    Component.onCompleted: {
        Brightness.refresh()
        Indicators.refresh()
    }

    function setText(n: int): void {
        textSize = Math.max(8, Math.min(24, n))
        Cmd.run(["omarchy-display-text-size", String(textSize)])
    }

    function rowVisible(r: int): bool {
        if (r === 0) return Brightness.available
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
            if (root.row === 0 && Brightness.available)
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

    // Header
    DetailHeader {
        width: parent.width
        title: qsTr("Display & Input")
        icon: "monitor"
        backable: false
    }

    // Unified Controls SettingGroup card
    SettingGroup {
        width: parent.width

        Item {
            visible: Brightness.available
            Layout.fillWidth: true
            implicitHeight: brightnessRow.implicitHeight

            SettingRow {
                id: brightnessRow

                anchors.fill: parent
                showDivider: false
                label: qsTr("Brightness")
                description: Math.round(Brightness.level * 100) + "%"

                Slider {
                    implicitWidth: Tokens.px(220)
                    style: "thin"
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
            }

            FocusRing {
                active: root.row === 0
                ringRadius: Tokens.radius.sm
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: nightLightRow.implicitHeight

            SettingRow {
                id: nightLightRow

                anchors.fill: parent
                showDivider: Brightness.available
                label: qsTr("Night Light")
                description: Indicators.nightLight ? qsTr("Warm tint active") : qsTr("Off")

                ToggleSwitch {
                    checked: Indicators.nightLight
                    accessibleLabel: qsTr("Toggle Night Light")
                    onToggled: {
                        root.row = 1
                        Indicators.toggleNightLight()
                    }
                }
            }

            FocusRing {
                active: root.row === 1
                ringRadius: Tokens.radius.sm
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: textSizeRow.implicitHeight

            SettingRow {
                id: textSizeRow

                anchors.fill: parent
                showDivider: true
                label: qsTr("Text Size")

                Stepper {
                    value: root.textSize
                    from: 8
                    to: 24
                    stepSize: 1
                    unit: "px"
                    accessibleLabel: qsTr("Text size")
                    onChanged: v => {
                        root.row = 2
                        root.setText(Math.round(v))
                    }
                }
            }

            FocusRing {
                active: root.row === 2
                ringRadius: Tokens.radius.sm
            }
        }
    }

    component HwTile: Rectangle {
        id: hwTile

        property string icon: ""
        property string label: ""
        property string detail: ""
        property bool active: false
        property bool focused: false

        signal toggled()

        implicitWidth: Tokens.px(140)
        implicitHeight: Math.max(Tokens.px(56), hwRow.implicitHeight + Tokens.px(20))
        radius: Tokens.radius.md
        activeFocusOnTab: true
        color: hwHover.hovered ? Tokens.veilHoverOf(Tokens.surfaceStyle) : Tokens.veilOf(Tokens.surfaceStyle)
        border.width: Tokens.hairlineWidth
        border.color: hwTile.active ? Tokens.color.accent : Tokens.veilBorderOf(Tokens.surfaceStyle)

        Behavior on color {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            ColorAnimation { duration: Tokens.motion.fast }
        }
        Behavior on border.color {
            enabled: !Tokens.reducedMotion && !Tokens.gameMode
            ColorAnimation { duration: Tokens.motion.fast }
        }

        Accessible.role: Accessible.Button
        Accessible.name: hwTile.detail !== "" ? hwTile.label + ", " + hwTile.detail : hwTile.label

        FocusRing {
            active: hwTile.focused || hwTile.activeFocus
            ringRadius: hwTile.radius
        }

        RowLayout {
            id: hwRow

            anchors.fill: parent
            anchors.leftMargin: Tokens.px(14)
            anchors.rightMargin: Tokens.px(14)
            anchors.topMargin: Tokens.px(10)
            anchors.bottomMargin: Tokens.px(10)
            spacing: Tokens.space.sm

            Rectangle {
                Layout.preferredWidth: Tokens.px(32)
                Layout.preferredHeight: Tokens.px(32)
                Layout.alignment: Qt.AlignVCenter
                radius: Tokens.radius.pill
                color: hwTile.active ? Tokens.color.accent : Tokens.veilHoverOf(Tokens.surfaceStyle)

                Behavior on color {
                    enabled: !Tokens.reducedMotion && !Tokens.gameMode
                    ColorAnimation { duration: Tokens.motion.fast }
                }

                Icon {
                    anchors.centerIn: parent
                    size: Tokens.size.iconMd
                    tone: hwTile.active ? "onAccent" : "muted"
                    icon: hwTile.icon
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.space.xxs

                TextLabel {
                    Layout.fillWidth: true
                    role: "sm"
                    font.weight: Font.Medium
                    tone: "primary"
                    text: hwTile.label
                }

                TextLabel {
                    Layout.fillWidth: true
                    visible: hwTile.detail !== ""
                    role: "caption"
                    tone: hwTile.active ? "accent" : "muted"
                    text: hwTile.detail
                }
            }
        }

        HoverHandler {
            id: hwHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                Tokens.keyboardNavigation = false
                hwTile.toggled()
            }
        }

        Keys.onSpacePressed: hwTile.toggled()
        Keys.onReturnPressed: hwTile.toggled()
    }

    // Adaptive Hardware grid (no orphan holes)
    ColumnLayout {
        visible: root.anyHw
        width: parent.width
        spacing: Tokens.space.xs

        TextLabel {
            role: "caption"
            tone: "muted"
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
            text: qsTr("Hardware")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(root.visibleHwCount, 3))
            columnSpacing: Tokens.space.sm
            rowSpacing: Tokens.space.sm

            HwTile {
                visible: root.hwLaptop
                Layout.fillWidth: true
                icon: "laptop"
                label: qsTr("Laptop Display")
                detail: root.laptopOff ? qsTr("Off") : qsTr("On")
                active: !root.laptopOff
                focused: root.row === 3
                onToggled: {
                    root.row = 3
                    root.toggleHw(3)
                }
            }

            HwTile {
                visible: root.hwLaptop
                Layout.fillWidth: true
                icon: "monitor"
                label: qsTr("Mirror Display")
                detail: root.mirrorOn ? qsTr("On") : qsTr("Off")
                active: root.mirrorOn
                focused: root.row === 4
                onToggled: {
                    root.row = 4
                    root.toggleHw(4)
                }
            }

            HwTile {
                visible: root.hwTouchpad
                Layout.fillWidth: true
                icon: "touchpad"
                label: qsTr("Touchpad")
                detail: root.touchpadOff ? qsTr("Off") : qsTr("On")
                active: !root.touchpadOff
                focused: root.row === 5
                onToggled: {
                    root.row = 5
                    root.toggleHw(5)
                }
            }

            HwTile {
                visible: root.hwTouchscreen
                Layout.fillWidth: true
                icon: "sparkles"
                label: qsTr("Touchscreen")
                detail: root.touchscreenOff ? qsTr("Off") : qsTr("On")
                active: !root.touchscreenOff
                focused: root.row === 6
                onToggled: {
                    root.row = 6
                    root.toggleHw(6)
                }
            }
        }
    }
}
