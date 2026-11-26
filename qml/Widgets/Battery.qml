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

    preferredWidth: 520
    hint: qsTr("←/→ or 1-3 profile · Esc close")
    compact: !Power.present

    readonly property var profiles: [
        { id: "power-saver", label: qsTr("Power Saver"), icon: "moon" },
        { id: "balanced", label: qsTr("Balanced"), icon: "battery" },
        { id: "performance", label: qsTr("Performance"), icon: "zap" }
    ]

    property string active: "balanced"
    property real healthUpower: 0
    readonly property real healthPct: Power.health > 0 ? Power.health : healthUpower
    readonly property int pctInt: Math.round(Power.level * 100)

    readonly property int activeIndex: {
        for (let i = 0; i < profiles.length; i++) {
            if (profiles[i].id === active)
                return i
        }
        return 1
    }

    readonly property color chargeColor: Power.low
        ? Tokens.color.danger
        : ((Power.charging || Power.full) ? Tokens.color.success : Tokens.color.accent)

    readonly property string badgeTone: Power.low
        ? "danger"
        : ((Power.charging || Power.full) ? "success" : "neutral")

    readonly property string timeSummary: {
        const t = Power.timeText(Power.secondsLeft)
        if (t !== "")
            return t + (Power.charging ? qsTr(" until full") : qsTr(" remaining"))
        if (Power.full)
            return qsTr("Fully charged · AC power")
        if (Power.charging)
            return qsTr("Connected to AC power")
        return qsTr("Running on battery")
    }

    function setProfile(profileId: string): void {
        root.active = profileId
        Cmd.run(["omarchy-powerprofiles-set", (Power.charging || Power.full) ? "ac" : "battery", profileId])
    }

    function setProfileIndex(idx: int): void {
        if (idx >= 0 && idx < root.profiles.length)
            root.setProfile(root.profiles[idx].id)
    }

    Component.onCompleted: Indicators.refresh()

    Keys.onPressed: function (e) {
        if (e.key === Qt.Key_Left) {
            root.setProfileIndex(Math.max(0, root.activeIndex - 1))
            e.accepted = true
        } else if (e.key === Qt.Key_Right) {
            root.setProfileIndex(Math.min(root.profiles.length - 1, root.activeIndex + 1))
            e.accepted = true
        } else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_3) {
            root.setProfileIndex(e.key - Qt.Key_1)
            e.accepted = true
        }
    }

    EmptyState {
        visible: !Power.present
        width: parent.width
        icon: "battery"
        title: qsTr("No battery detected")
        description: qsTr("This machine is running directly on AC power.")
    }

    Card {
        visible: Power.present
        width: parent.width
        implicitHeight: heroRow.implicitHeight + verticalPadding * 2

        RowLayout {
            id: heroRow

            width: parent.width
            spacing: Tokens.space.lg

            UsageRing {
                size: Tokens.px(92)
                thickness: Tokens.px(8)
                values: [1]
                fill: Power.level
                accent: root.chargeColor
                centerText: root.pctInt + "%"
                centerSubtext: Power.charging ? qsTr("AC") : qsTr("BAT")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.xs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.sm

                    TextLabel {
                        role: "h1"
                        tabular: true
                        text: root.pctInt + "%"
                    }

                    Badge {
                        text: Power.stateText !== "" ? Power.stateText : qsTr("On Battery")
                        tone: root.badgeTone
                    }

                    Item { Layout.fillWidth: true }
                }

                TextLabel {
                    Layout.fillWidth: true
                    role: "sm"
                    tone: "muted"
                    text: root.timeSummary
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.space.xxs
                    spacing: Tokens.space.md

                    TextLabel {
                        role: "caption"
                        tone: "secondary"
                        tabular: true
                        text: Power.watts > 0.05
                            ? (Power.watts.toFixed(1) + " W " + (Power.charging ? qsTr("in") : qsTr("draw")))
                            : (Power.full ? qsTr("Idle on AC") : qsTr("Draw —"))
                    }

                    TextLabel {
                        role: "caption"
                        tone: "secondary"
                        tabular: true
                        text: qsTr("Health %1").arg(root.healthPct > 0 ? Math.round(root.healthPct) + "%" : qsTr("Good"))
                    }
                }
            }
        }
    }

    Card {
        width: parent.width
        implicitHeight: ctrlCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: ctrlCol

            width: parent.width
            spacing: Tokens.space.md

            SegmentedControl {
                visible: Power.present
                Layout.fillWidth: true
                stretch: true
                labelled: true
                accessibleLabel: qsTr("Power profile")
                options: root.profiles
                current: root.active
                onSelected: function (id) {
                    root.setProfile(id)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.md

                Icon {
                    icon: "coffee"
                    size: Tokens.size.iconMd
                    tone: Indicators.stayAwake ? "accent" : "muted"
                    framed: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xxs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "body"
                        font.weight: Font.Medium
                        text: qsTr("Stay Awake")
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "caption"
                        tone: "muted"
                        text: qsTr("Keep display and system awake while idle")
                    }
                }

                ToggleSwitch {
                    checked: Indicators.stayAwake
                    accessibleLabel: qsTr("Stay Awake")
                    onToggled: Indicators.toggleStayAwake()
                }
            }
        }
    }

    Process {
        running: Power.present && Power.health <= 0
        command: ["bash", "-c", "upower -i $(upower -e | grep -i bat | head -1) | grep -E '^ *capacity:'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /([\d.]+)\s*%/.exec(text)
                if (m)
                    root.healthUpower = parseFloat(m[1])
            }
        }
    }

    Process {
        running: Power.present
        command: ["omarchy-powerprofiles-list", "--active-state"]
        stdout: StdioCollector {
            onStreamFinished: {
                text.split("\n").forEach(function (l) {
                    const t = l.split("\t")
                    if (t.length >= 2 && t[1].trim() === "1")
                        root.active = t[0].trim()
                })
            }
        }
    }
}
