pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"
import "../QuickshellDS/Patterns"

WidgetSurface {
    id: root

    preferredWidth: 460
    readonly property bool wantsKeyboard: editingLocation
    readonly property bool capturesEscape: editingLocation
    hint: qsTr("R refresh · L location · Esc close")

    readonly property string weatherState: WeatherData.state === "empty" ? "loading" : WeatherData.state
    readonly property var w: WeatherData.w
    property bool editingLocation: false

    dataLoading: weatherState === "loading"
    compact: weatherState !== "ok" && !editingLocation

    Component.onCompleted: WeatherData.refreshIfStale()

    function mapWeatherIcon(name: string): string {
        switch (name) {
        case "cloud-bolt": return "cloud-lightning"
        case "rain":       return "cloud-rain"
        case "fog":        return "cloud"
        case "cloud-moon": return "moon"
        default:           return name || "cloud"
        }
    }

    function openLocationEdit(): void {
        locationField.text = IslandState.weatherLocation
        editingLocation = true
        Qt.callLater(() => locationField.focusInput())
    }

    function applyLocation(): void {
        IslandState.weatherLocation = locationField.text.trim()
        IslandState.save()
        editingLocation = false
        WeatherData.refresh()
        root.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (root.editingLocation) {
            if (event.key === Qt.Key_Escape) {
                IslandState.touch(true)
                root.editingLocation = false
                root.forceActiveFocus()
                event.accepted = true
            }
            return
        }
        if (event.key === Qt.Key_R) {
            IslandState.touch(true)
            WeatherData.refresh()
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            IslandState.touch(true)
            root.openLocationEdit()
            event.accepted = true
        }
    }

    // Loading state
    RowLayout {
        visible: root.weatherState === "loading"
        width: parent.width
        spacing: Tokens.space.md

        LoadingSpinner {
            running: root.visible && root.weatherState === "loading"
        }

        TextLabel {
            Layout.fillWidth: true
            role: "subtitle"
            tone: "muted"
            text: qsTr("Fetching weather…")
        }
    }

    // Error state
    EmptyState {
        visible: root.weatherState === "error"
        width: parent.width
        icon: "alert-triangle"
        title: qsTr("Weather unavailable")
        description: qsTr("Couldn't load weather. Check your connection or press R to retry.")
    }

    // Hero Card
    Card {
        visible: root.weatherState === "ok"
        width: parent.width
        horizontalPadding: Tokens.space.xl
        verticalPadding: Tokens.space.lg
        implicitHeight: heroCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: heroCol

            width: parent.width
            spacing: Tokens.space.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space.md

                Icon {
                    icon: root.mapWeatherIcon(root.w.icon ?? "cloud")
                    size: Tokens.size.iconXl
                    tone: root.w.icon === "sun" ? "warning" : "accent"
                    framed: true
                }

                TextLabel {
                    role: "h1"
                    tabular: true
                    text: (root.w.temp ?? 0) + "°"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.space.xxs

                    TextLabel {
                        Layout.fillWidth: true
                        role: "subtitle"
                        font.weight: Font.Medium
                        text: root.w.desc ?? ""
                    }

                    TextLabel {
                        Layout.fillWidth: true
                        role: "sm"
                        tone: "muted"
                        tabular: true
                        text: qsTr("Feels like %1° · %2").arg(root.w.feels ?? 0).arg(root.w.place ?? "")
                    }
                }

                Button {
                    icon: "pin"
                    size: "sm"
                    variant: root.editingLocation ? "primary" : "ghost"
                    accessibleLabel: qsTr("Edit weather location")
                    onClicked: root.editingLocation ? root.editingLocation = false : root.openLocationEdit()
                }

                Button {
                    icon: "refresh-cw"
                    size: "sm"
                    variant: "ghost"
                    accessibleLabel: qsTr("Refresh weather")
                    onClicked: WeatherData.refresh()
                }
            }

            // Inline location editor
            RowLayout {
                visible: root.editingLocation
                Layout.fillWidth: true
                spacing: Tokens.space.xs

                TextField {
                    id: locationField

                    Layout.fillWidth: true
                    icon: "globe"
                    placeholderText: qsTr("City name (empty = auto IP)…")
                    accessibleLabel: qsTr("Weather location")
                    onAccepted: root.applyLocation()
                }

                Button {
                    text: qsTr("Save")
                    size: "sm"
                    variant: "primary"
                    onClicked: root.applyLocation()
                }
            }
        }
    }

    // Multi-layer metrics row
    RowLayout {
        visible: root.weatherState === "ok"
        width: parent.width
        spacing: Tokens.space.sm

        Card {
            Layout.fillWidth: true
            horizontalPadding: Tokens.space.md
            verticalPadding: Tokens.space.md
            implicitHeight: feelsCol.implicitHeight + verticalPadding * 2

            ColumnLayout {
                id: feelsCol

                width: parent.width
                spacing: Tokens.space.xs

                RowLayout {
                    spacing: Tokens.space.xs

                    Icon { icon: "thermometer"; size: Tokens.size.iconSm; tone: "accent" }
                    TextLabel { role: "caption"; tone: "muted"; text: qsTr("FEELS LIKE") }
                }

                TextLabel {
                    role: "h2"
                    tabular: true
                    text: (root.w.feels ?? 0) + "°"
                }

                TextLabel {
                    role: "caption"
                    tone: "muted"
                    tabular: true
                    text: qsTr("High %1° · Low %2°").arg(root.w.hi ?? 0).arg(root.w.lo ?? 0)
                }
            }
        }

        Card {
            Layout.fillWidth: true
            horizontalPadding: Tokens.space.md
            verticalPadding: Tokens.space.md
            implicitHeight: humCol.implicitHeight + verticalPadding * 2

            ColumnLayout {
                id: humCol

                width: parent.width
                spacing: Tokens.space.xs

                RowLayout {
                    spacing: Tokens.space.xs

                    Icon { icon: "droplets"; size: Tokens.size.iconSm; tone: "info" }
                    TextLabel { role: "caption"; tone: "muted"; text: qsTr("HUMIDITY") }
                }

                TextLabel {
                    role: "h2"
                    tabular: true
                    text: (root.w.humidity ?? 0) + "%"
                }

                UsageBar {
                    Layout.fillWidth: true
                    progress: Math.max(0, Math.min(1, (root.w.humidity ?? 0) / 100))
                    fillColor: Tokens.color.info
                }
            }
        }

        Card {
            Layout.fillWidth: true
            horizontalPadding: Tokens.space.md
            verticalPadding: Tokens.space.md
            implicitHeight: ageCol.implicitHeight + verticalPadding * 2

            ColumnLayout {
                id: ageCol

                width: parent.width
                spacing: Tokens.space.xs

                RowLayout {
                    spacing: Tokens.space.xs

                    Icon { icon: "wind"; size: Tokens.size.iconSm; tone: "muted" }
                    TextLabel { role: "caption"; tone: "muted"; text: qsTr("UPDATED") }
                }

                TextLabel {
                    role: "h2"
                    tabular: true
                    text: WeatherData.age < 120000 ? qsTr("Now") : Math.round(WeatherData.age / 60000) + "m"
                }

                TextLabel {
                    role: "caption"
                    tone: "muted"
                    text: IslandState.weatherLocation !== "" ? IslandState.weatherLocation : qsTr("Auto IP")
                }
            }
        }
    }

    // Temperature range strip
    Card {
        visible: root.weatherState === "ok"
        width: parent.width
        horizontalPadding: Tokens.space.lg
        verticalPadding: Tokens.space.md
        implicitHeight: rangeCol.implicitHeight + verticalPadding * 2

        ColumnLayout {
            id: rangeCol

            width: parent.width
            spacing: Tokens.space.xs

            TextLabel {
                role: "caption"
                tone: "muted"
                text: qsTr("TODAY'S RANGE")
            }

            BarChart {
                Layout.fillWidth: true
                implicitHeight: Tokens.px(54)
                values: [
                    Math.max(0, (root.w.lo ?? 0) + 20),
                    Math.max(0, (root.w.feels ?? 0) + 20),
                    Math.max(0, (root.w.temp ?? 0) + 20),
                    Math.max(0, (root.w.hi ?? 0) + 20)
                ]
                maxValue: Math.max(40, (root.w.hi ?? 0) + 25)
                labels: [
                    qsTr("Low %1°").arg(root.w.lo ?? 0),
                    qsTr("Feels %1°").arg(root.w.feels ?? 0),
                    qsTr("Now %1°").arg(root.w.temp ?? 0),
                    qsTr("High %1°").arg(root.w.hi ?? 0)
                ]
                barColor: Tokens.color.accent
            }
        }
    }
}
