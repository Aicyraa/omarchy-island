pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Core"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    property string currentTab: "appearance"

    readonly property var barItemCatalog: [
        { key: "workspaces",    label: qsTr("Workspaces"),    icon: "layout-grid" },
        { key: "clock",         label: qsTr("Clock"),         icon: "clock" },
        { key: "weather",       label: qsTr("Weather"),       icon: "cloud-sun" },
        { key: "visualizer",    label: qsTr("Visualizer"),    icon: "activity" },
        { key: "wifi",          label: qsTr("Wi-Fi"),         icon: "wifi" },
        { key: "bluetooth",     label: qsTr("Bluetooth"),     icon: "bluetooth" },
        { key: "battery",       label: qsTr("Battery"),       icon: "battery" },
        { key: "notifications", label: qsTr("Notifications"), icon: "bell" },
        { key: "audio",         label: qsTr("Audio"),         icon: "volume" },
        { key: "system",        label: qsTr("System"),        icon: "cpu" },
        { key: "capture",       label: qsTr("Capture"),       icon: "camera" },
        { key: "look",          label: qsTr("Look & Theme"),  icon: "sparkles" },
        { key: "clipboard",     label: qsTr("Clipboard"),     icon: "clipboard" },
        { key: "theme",         label: qsTr("Palette"),       icon: "palette" },
        { key: "power",         label: qsTr("Power"),         icon: "power" }
    ]

    readonly property var presetCatalog: [
        {
            id: "obsidian-pill",
            title: qsTr("Obsidian Pill"),
            attributes: [qsTr("Classic"), qsTr("Pill"), qsTr("Capsule Rail"), qsTr("Comfortable")],
            chips: [Tokens.color.bg, Tokens.color.surface, Tokens.color.accent]
        },
        {
            id: "frosted-liquid",
            title: qsTr("Frosted Liquid"),
            attributes: [qsTr("Liquid Glass"), qsTr("Pill"), qsTr("Capsule Rail"), qsTr("Comfortable")],
            chips: [Tokens.color.liquidGround, Tokens.color.accent, Tokens.color.info]
        },
        {
            id: "minimal-docked",
            title: qsTr("Minimal Docked"),
            attributes: [qsTr("Classic"), qsTr("Notch"), qsTr("Hairline Rail"), qsTr("Compact")],
            chips: [Tokens.color.surfaceRaised, Tokens.color.borderStrong, Tokens.color.textMuted]
        }
    ]

    function isPresetActive(presetId: string): bool {
        if (presetId === "obsidian-pill") {
            return ConfigStore.surfaceStyle === "classic"
                && !ConfigStore.followCompositorRadius
                && ConfigStore.density === "comfortable"
                && ConfigStore.barStyle === "pill"
                && ConfigStore.scrollRailVariant === "capsule"
                && ConfigStore.shadowsEnabled
        }
        if (presetId === "frosted-liquid") {
            return ConfigStore.surfaceStyle === "liquid"
                && !ConfigStore.followCompositorRadius
                && ConfigStore.density === "comfortable"
                && ConfigStore.barStyle === "pill"
                && ConfigStore.scrollRailVariant === "capsule"
                && ConfigStore.shadowsEnabled
        }
        if (presetId === "minimal-docked") {
            return ConfigStore.surfaceStyle === "classic"
                && !ConfigStore.followCompositorRadius
                && ConfigStore.density === "compact"
                && ConfigStore.barStyle === "notch"
                && ConfigStore.scrollRailVariant === "hairline"
                && ConfigStore.shadowsEnabled
        }
        return false
    }

    preferredWidth: 680
    scrollTarget: settingsFlick
    hint: qsTr("Tab switch tab · Esc close")

    onCurrentTabChanged: settingsFlick.contentY = 0

    Keys.onTabPressed: event => {
        tabStrip.stepTab(1)
        event.accepted = true
    }

    RowLayout {
        width: parent.width
        spacing: Tokens.space.md

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            icon: "settings"
            title: qsTr("Island Settings")
        }

        Button {
            text: qsTr("Reset")
            variant: "ghost"
            size: "sm"
            icon: "rotate-ccw"
            accessibleLabel: qsTr("Reset all settings to defaults")
            onClicked: ConfigStore.resetDefaults()
        }
    }

    TabStrip {
        id: tabStrip

        width: parent.width
        accessibleLabel: qsTr("Settings sections")
        current: root.currentTab
        tabs: [
            { id: "appearance", label: qsTr("Appearance") },
            { id: "layout",     label: qsTr("Layout") },
            { id: "behavior",   label: qsTr("Behavior") },
            { id: "presets",    label: qsTr("Presets") }
        ]
        onPicked: id => {
            root.currentTab = id
            settingsFlick.contentY = 0
            tabFade.restart()
        }
    }

    NumberAnimation {
        id: tabFade
        target: tabContent
        property: "opacity"
        from: 0.25
        to: 1.0
        duration: (Tokens.reducedMotion || Tokens.gameMode) ? 0 : Math.round(120 * Tokens.motionScale)
        easing.type: Easing.OutCubic
    }

    Flickable {
        id: settingsFlick

        width: parent.width
        height: Math.min(tabContent.implicitHeight, Tokens.px(430))
        clip: contentHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: tabContent.implicitHeight

        ColumnLayout {
            id: tabContent

            width: settingsFlick.width
            spacing: Tokens.space.lg

            // ── APPEARANCE ──────────────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.currentTab === "appearance"
                spacing: Tokens.space.lg

                SettingGroup {
                    title: qsTr("Material & Geometry")

                    SettingRow {
                        label: qsTr("Surface Material")
                        showDivider: false

                        SegmentedControl {
                            accessibleLabel: qsTr("Surface Material")
                            current: ConfigStore.surfaceStyle
                            options: [
                                { id: "classic", label: qsTr("Classic") },
                                { id: "glass",   label: qsTr("Glass") },
                                { id: "liquid",  label: qsTr("Liquid") }
                            ]
                            onSelected: id => ConfigStore.surfaceStyle = id
                        }
                    }

                    SettingRow {
                        label: qsTr("Corner Radius")

                        SegmentedControl {
                            accessibleLabel: qsTr("Corner Radius")
                            current: ConfigStore.followCompositorRadius ? "compositor" : "rounded"
                            options: [
                                { id: "rounded",    label: qsTr("Rounded") },
                                { id: "compositor", label: qsTr("Compositor") }
                            ]
                            onSelected: id => ConfigStore.followCompositorRadius = (id === "compositor")
                        }
                    }

                    SettingRow {
                        label: qsTr("Density")

                        SegmentedControl {
                            accessibleLabel: qsTr("Density")
                            current: ConfigStore.density
                            options: [
                                { id: "compact",     label: qsTr("Compact") },
                                { id: "comfortable", label: qsTr("Comfortable") },
                                { id: "spacious",    label: qsTr("Spacious") }
                            ]
                            onSelected: id => ConfigStore.density = id
                        }
                    }

                    SettingRow {
                        label: qsTr("UI Scale")

                        Slider {
                            accessibleLabel: qsTr("UI Scale")
                            from: 0.85
                            to: 1.25
                            stepSize: 0.05
                            decimals: 2
                            unit: "x"
                            showReadout: true
                            value: ConfigStore.userScale
                            onMoved: value => ConfigStore.userScale = Math.round(value * 100) / 100
                        }
                    }

                    SettingRow {
                        label: qsTr("Drop Shadows")

                        ToggleSwitch {
                            accessibleLabel: qsTr("Drop Shadows")
                            checked: ConfigStore.shadowsEnabled
                            onToggled: checked => ConfigStore.shadowsEnabled = checked
                        }
                    }
                }

                SettingGroup {
                    title: qsTr("Detached ScrollRail")

                    SettingRow {
                        label: qsTr("Rail Variant")
                        showDivider: false

                        SegmentedControl {
                            accessibleLabel: qsTr("Rail Variant")
                            current: ConfigStore.scrollRailVariant
                            options: [
                                { id: "capsule",  label: qsTr("Capsule") },
                                { id: "hairline", label: qsTr("Hairline") },
                                { id: "gauge",    label: qsTr("Gauge") }
                            ]
                            onSelected: id => ConfigStore.scrollRailVariant = id
                        }
                    }

                    SettingRow {
                        label: qsTr("Rail Side")

                        SegmentedControl {
                            accessibleLabel: qsTr("Rail Side")
                            current: ConfigStore.scrollRailSide
                            options: [
                                { id: "left",  label: qsTr("Left") },
                                { id: "right", label: qsTr("Right") }
                            ]
                            onSelected: id => ConfigStore.scrollRailSide = id
                        }
                    }
                }
            }

            // ── LAYOUT ──────────────────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.currentTab === "layout"
                spacing: Tokens.space.lg

                SettingGroup {
                    title: qsTr("Bar Position & Pattern")

                    SettingRow {
                        label: qsTr("Screen Edge")
                        showDivider: false

                        SegmentedControl {
                            accessibleLabel: qsTr("Screen Edge")
                            current: ConfigStore.barPosition
                            options: [
                                { id: "top",    label: qsTr("Top") },
                                { id: "bottom", label: qsTr("Bottom") },
                                { id: "left",   label: qsTr("Left") },
                                { id: "right",  label: qsTr("Right") }
                            ]
                            onSelected: id => ConfigStore.barPosition = id
                        }
                    }

                    SettingRow {
                        label: qsTr("Bar Pattern")

                        SegmentedControl {
                            accessibleLabel: qsTr("Bar Pattern")
                            current: ConfigStore.barStyle
                            options: [
                                { id: "pill",  label: qsTr("Pill") },
                                { id: "notch", label: qsTr("Notch") },
                                { id: "full",  label: qsTr("Full") }
                            ]
                            onSelected: id => ConfigStore.barStyle = id
                        }
                    }
                }

                SettingGroup {
                    title: qsTr("Visible Topbar Icons")

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Tokens.space.md
                        Layout.rightMargin: Tokens.space.md
                        Layout.topMargin: Tokens.space.sm
                        Layout.bottomMargin: Tokens.space.sm
                        columns: 3
                        columnSpacing: Tokens.space.sm
                        rowSpacing: Tokens.space.xs

                        Repeater {
                            model: root.barItemCatalog

                            Item {
                                id: barItemCell

                                required property var modelData
                                readonly property bool itemVisible: ConfigStore.barItemVisible(barItemCell.modelData.key)

                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(Tokens.px(40), barItemRow.implicitHeight + Tokens.space.sm * 2)

                                RowLayout {
                                    id: barItemRow

                                    anchors.fill: parent
                                    anchors.leftMargin: Tokens.space.md
                                    anchors.rightMargin: Tokens.space.md
                                    anchors.topMargin: Tokens.space.sm
                                    anchors.bottomMargin: Tokens.space.sm
                                    spacing: Tokens.space.sm

                                    Icon {
                                        icon: barItemCell.modelData.icon
                                        size: Tokens.size.iconSm
                                        tone: barItemCell.itemVisible ? "accent" : "muted"
                                    }

                                    TextLabel {
                                        Layout.fillWidth: true
                                        role: "body"
                                        text: barItemCell.modelData.label
                                    }

                                    ToggleSwitch {
                                        accessibleLabel: barItemCell.modelData.label
                                        checked: barItemCell.itemVisible
                                        onToggled: checked => ConfigStore.setBarItem(barItemCell.modelData.key, checked)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── BEHAVIOR ────────────────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.currentTab === "behavior"
                spacing: Tokens.space.lg

                SettingGroup {
                    title: qsTr("Menu & Motion")

                    SettingRow {
                        label: qsTr("Omarchy Menu Mode")
                        showDivider: false

                        SegmentedControl {
                            accessibleLabel: qsTr("Omarchy Menu Mode")
                            current: ConfigStore.menuPresentation
                            options: [
                                { id: "morphed",   label: qsTr("Topbar Morphed") },
                                { id: "spotlight", label: qsTr("Centered Spotlight") }
                            ]
                            onSelected: id => ConfigStore.menuPresentation = id
                        }
                    }

                    SettingRow {
                        label: qsTr("Reduced Motion")

                        ToggleSwitch {
                            accessibleLabel: qsTr("Reduced Motion")
                            checked: ConfigStore.reducedMotion
                            onToggled: checked => ConfigStore.reducedMotion = checked
                        }
                    }

                    SettingRow {
                        label: qsTr("Game Mode")

                        ToggleSwitch {
                            accessibleLabel: qsTr("Game Mode")
                            checked: ConfigStore.gameMode
                            onToggled: checked => ConfigStore.gameMode = checked
                        }
                    }

                    SettingRow {
                        label: qsTr("Hide in Fullscreen")

                        ToggleSwitch {
                            accessibleLabel: qsTr("Hide in Fullscreen")
                            checked: ConfigStore.hideInFullscreen
                            onToggled: checked => ConfigStore.hideInFullscreen = checked
                        }
                    }

                    SettingRow {
                        label: qsTr("Motion Speed")

                        Slider {
                            accessibleLabel: qsTr("Motion Speed")
                            enabled: !ConfigStore.reducedMotion && !ConfigStore.gameMode
                            opacity: enabled ? 1.0 : 0.45
                            from: 0.6
                            to: 1.4
                            stepSize: 0.1
                            decimals: 1
                            unit: "x"
                            showReadout: true
                            value: ConfigStore.motionScale
                            onMoved: value => ConfigStore.motionScale = Math.round(value * 10) / 10
                        }
                    }
                }
            }

            // ── PRESETS ─────────────────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.currentTab === "presets"
                spacing: Tokens.space.sm

                Repeater {
                    model: root.presetCatalog

                    Card {
                        id: presetCard

                        required property var modelData
                        readonly property bool isActive: root.isPresetActive(presetCard.modelData.id)

                        Layout.fillWidth: true
                        implicitHeight: presetRow.implicitHeight + verticalPadding * 2
                        hovered: presetHover.hovered
                        border.color: presetCard.isActive
                            ? Tokens.color.accent
                            : (presetHover.hovered ? Tokens.color.borderStrong : Tokens.veilBorderOf(Tokens.surfaceStyle))
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: presetCard.modelData.title

                        FocusRing {
                            active: presetCard.activeFocus
                            ringRadius: presetCard.radius
                        }

                        RowLayout {
                            id: presetRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.space.md

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.space.xs

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.space.sm

                                    TextLabel {
                                        role: "subtitle"
                                        font.weight: Font.Medium
                                        text: presetCard.modelData.title
                                    }

                                    Badge {
                                        visible: presetCard.isActive
                                        text: qsTr("Active")
                                        tone: "accent"
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Tokens.space.xs

                                    Repeater {
                                        model: presetCard.modelData.attributes

                                        Rectangle {
                                            id: attrChip

                                            required property string modelData

                                            implicitWidth: chipLabel.implicitWidth + Tokens.space.md
                                            implicitHeight: chipLabel.implicitHeight + Tokens.space.xs
                                            radius: Tokens.radius.pill
                                            color: Tokens.veilOf(Tokens.surfaceStyle)
                                            border.width: Tokens.hairlineWidth
                                            border.color: Tokens.veilBorderOf(Tokens.surfaceStyle)

                                            TextLabel {
                                                id: chipLabel

                                                anchors.centerIn: parent
                                                role: "caption"
                                                tone: "secondary"
                                                text: attrChip.modelData
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Tokens.space.xs

                                Repeater {
                                    model: presetCard.modelData.chips

                                    Rectangle {
                                        required property color modelData

                                        width: Tokens.px(16)
                                        height: Tokens.px(16)
                                        radius: Tokens.radius.pill
                                        color: modelData
                                        border.width: Tokens.hairlineWidth
                                        border.color: Tokens.color.borderStrong
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            id: presetHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                Tokens.keyboardNavigation = false
                                ConfigStore.applyPreset(presetCard.modelData.id)
                            }
                        }

                        Keys.onSpacePressed: ConfigStore.applyPreset(presetCard.modelData.id)
                        Keys.onReturnPressed: ConfigStore.applyPreset(presetCard.modelData.id)
                    }
                }
            }
        }
    }
}
