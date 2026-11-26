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
        { key: "workspaces",    label: qsTr("Workspaces") },
        { key: "clock",         label: qsTr("Clock") },
        { key: "weather",       label: qsTr("Weather") },
        { key: "visualizer",    label: qsTr("Visualizer") },
        { key: "wifi",          label: qsTr("Wi-Fi") },
        { key: "bluetooth",     label: qsTr("Bluetooth") },
        { key: "battery",       label: qsTr("Battery") },
        { key: "notifications", label: qsTr("Notifications") },
        { key: "audio",         label: qsTr("Audio") },
        { key: "system",        label: qsTr("System") },
        { key: "capture",       label: qsTr("Capture") },
        { key: "look",          label: qsTr("Look & Theme") },
        { key: "clipboard",     label: qsTr("Clipboard") },
        { key: "theme",         label: qsTr("Palette") },
        { key: "power",         label: qsTr("Power") }
    ]

    readonly property var presetCatalog: [
        {
            id: "obsidian-pill",
            title: qsTr("Obsidian Pill"),
            description: qsTr("Classic opaque surface, comfortable spacing, floating pill bar, and capsule scroll rail."),
            chips: [Tokens.color.bg, Tokens.color.surface, Tokens.color.accent]
        },
        {
            id: "frosted-liquid",
            title: qsTr("Frosted Liquid"),
            description: qsTr("Translucent directional-lit liquid glass, comfortable spacing, floating pill, and capsule rail."),
            chips: [Tokens.color.liquidGround, Tokens.color.accent, Tokens.color.info]
        },
        {
            id: "minimal-docked",
            title: qsTr("Minimal Docked"),
            description: qsTr("Compact classic surface docked as a screen-edge notch with a subtle hairline scroll rail."),
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

    preferredWidth: 620
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

        Icon {
            icon: "settings"
            size: Tokens.size.iconMd
            tone: "accent"
            framed: true
        }

        DetailHeader {
            Layout.fillWidth: true
            backable: false
            title: qsTr("Island Settings")
            detail: qsTr("Customize surface material, topbar layout, and motion")
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
        height: 310
        clip: true
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
                        description: qsTr("Backdrop translucency and rim lighting")
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
                        description: qsTr("Use Island pill radii or match compositor rounding")

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
                        description: qsTr("Control height and spacing scale")

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
                        description: qsTr("Multiplier for typography, icons, and spacing")

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
                        description: qsTr("Soft elevation shadows beneath floating surfaces")

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
                        description: qsTr("Visual indicator style for scrollable panels")
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
                        description: qsTr("Edge placement relative to the active widget")

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
                        description: qsTr("Anchor the bar to any screen edge")
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
                        description: qsTr("Floating pill, edge-attached notch, or full-width bar")

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
                    title: qsTr("Visible Topbar Sections & Icons")

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Tokens.space.xl
                        Layout.rightMargin: Tokens.space.xl
                        Layout.topMargin: Tokens.space.md
                        Layout.bottomMargin: Tokens.space.md
                        columns: 2
                        columnSpacing: Tokens.space.xl
                        rowSpacing: Tokens.space.sm

                        Repeater {
                            model: root.barItemCatalog

                            RowLayout {
                                id: barItemRow

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: Tokens.px(32)
                                spacing: Tokens.space.sm

                                TextLabel {
                                    Layout.fillWidth: true
                                    role: "body"
                                    text: barItemRow.modelData.label
                                }

                                ToggleSwitch {
                                    accessibleLabel: barItemRow.modelData.label
                                    checked: ConfigStore.barItemVisible(barItemRow.modelData.key)
                                    onToggled: checked => ConfigStore.setBarItem(barItemRow.modelData.key, checked)
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
                        description: qsTr("Morph the topbar or open a centered spotlight")
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
                        description: qsTr("Disable spring and transition animations")

                        ToggleSwitch {
                            accessibleLabel: qsTr("Reduced Motion")
                            checked: ConfigStore.reducedMotion
                            onToggled: checked => ConfigStore.reducedMotion = checked
                        }
                    }

                    SettingRow {
                        label: qsTr("Game Mode")
                        description: qsTr("Disable shadows and animations for minimum latency")

                        ToggleSwitch {
                            accessibleLabel: qsTr("Game Mode")
                            checked: ConfigStore.gameMode
                            onToggled: checked => ConfigStore.gameMode = checked
                        }
                    }

                    SettingRow {
                        label: qsTr("Hide in Fullscreen")
                        description: qsTr("Automatically conceal the bar when an app is fullscreen")

                        ToggleSwitch {
                            accessibleLabel: qsTr("Hide in Fullscreen")
                            checked: ConfigStore.hideInFullscreen
                            onToggled: checked => ConfigStore.hideInFullscreen = checked
                        }
                    }

                    SettingRow {
                        label: qsTr("Motion Speed")
                        description: qsTr("Scale animation durations across Island")

                        Slider {
                            accessibleLabel: qsTr("Motion Speed")
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
                                spacing: Tokens.space.xxs

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

                                TextLabel {
                                    Layout.fillWidth: true
                                    role: "sm"
                                    tone: "muted"
                                    singleLine: false
                                    text: presetCard.modelData.description
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
