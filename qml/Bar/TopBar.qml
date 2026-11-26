pragma ComponentBehavior: Bound

import QtQuick
import "../Core"
import "../Services"
import "../QuickshellDS/Theme"
import "../QuickshellDS/Primitives"
import "../QuickshellDS/Components"

// TopBar: workspaces | grouped widget icons | time + weather + battery + audio visualizer.
Item {
  id: root

  property var win: null
  readonly property string screenName: win ? win.screenName : ""
  readonly property bool vertical: win ? win.isVertical : false
  readonly property real edgePad: 14

  function widthFor() {
    return Math.ceil(barGrid.implicitWidth + 2 * edgePad)
  }

  function heightFor() {
    return Math.ceil(barGrid.implicitHeight + 2 * edgePad)
  }

  function mapWeatherIcon(name) {
    switch (name) {
    case "sun":        return "sun"
    case "moon":       return "moon"
    case "cloud-sun":  return "cloud-sun"
    case "cloud-moon": return "cloud"
    case "cloud-bolt": return "cloud-lightning"
    case "cloud-snow": return "cloud-snow"
    case "rain":       return "cloud-rain"
    default:           return "cloud"
    }
  }

  component BarDivider: Rectangle {
    width: root.vertical ? 16 : Tokens.hairlineWidth
    height: root.vertical ? Tokens.hairlineWidth : 14
    color: Tokens.color.hairline
  }

  Grid {
    id: barGrid
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 40
    columnSpacing: Tokens.space.xs
    rowSpacing: Tokens.space.xs
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    WorkspaceStrip {
      id: workspaceStrip
      vertical: root.vertical
      visible: ConfigStore.barItemVisible("workspaces")
    }

    BarDivider {
      visible: ConfigStore.barItemVisible("workspaces")
    }

    // Recording / Dictation badge
    Item {
      id: recBadge
      visible: ConfigStore.barItemVisible("recording") && (Indicators.recording || Indicators.dictation !== "idle")
      implicitWidth: recRow.implicitWidth + Tokens.space.sm * 2
      implicitHeight: 24

      activeFocusOnTab: visible
      Accessible.role: Accessible.Button
      Accessible.name: Indicators.recording ? qsTr("Screen recording active") : qsTr("Dictation active")

      Keys.onSpacePressed: function(e) {
        IslandState.toggleWidget("capture", root.screenName)
        e.accepted = true
      }
      Keys.onReturnPressed: function(e) {
        IslandState.toggleWidget("capture", root.screenName)
        e.accepted = true
      }

      Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.pill
        color: {
          var c = Indicators.recording ? Tokens.color.danger : Tokens.color.accent
          return Qt.rgba(c.r, c.g, c.b, recMouse.containsMouse ? 0.24 : 0.14)
        }

        Behavior on color {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          ColorAnimation { duration: Tokens.motion.fast }
        }
      }

      FocusRing {
        active: recBadge.activeFocus
        ringRadius: Tokens.radius.pill
      }

      Row {
        id: recRow
        anchors.centerIn: parent
        spacing: Tokens.space.xs

        StatusDot {
          anchors.verticalCenter: parent.verticalCenter
          size: 6
          tone: Indicators.recording ? "danger" : "accent"
          pulse: true
        }

        Icon {
          anchors.verticalCenter: parent.verticalCenter
          name: Indicators.recording ? "video" : "mic"
          size: 13
          tone: Indicators.recording ? "danger" : "accent"
        }
      }

      MouseArea {
        id: recMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: IslandState.toggleWidget("capture", root.screenName)
      }
    }

    // ---- Grouped Widget Icons ----
    BarIconButton {
      visible: ConfigStore.barItemVisible("wifi") && Net.hasWifi
      name: Net.enabled ? "wifi" : "wifi-off"
      tone: Net.connected ? "primary" : "muted"
      accessibleName: Net.connected ? qsTr("Wi-Fi connected: %1").arg(Net.ssid) : qsTr("Wi-Fi")
      onClicked: IslandState.toggleWidget("wifi", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("bluetooth") && Bt.hasAdapter
      name: Bt.enabled ? "bluetooth" : "bluetooth-off"
      tone: Bt.connectedDevices.length > 0 ? "accent" : (Bt.enabled ? "primary" : "muted")
      badgeDot: Bt.connectedDevices.length > 0
      badgeTone: "accent"
      badgePosition: "bottom"
      accessibleName: Bt.connectedDevices.length > 0
        ? qsTr("Bluetooth connected: %1").arg(Bt.connectedName)
        : qsTr("Bluetooth")
      onClicked: IslandState.toggleWidget("bluetooth", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("notifications")
      name: Indicators.dnd ? "bell-off" : "bell"
      tone: Indicators.dnd ? "muted" : "primary"
      badgeDot: Notifs.liveCount > 0
      badgeTone: "accent"
      badgePosition: "topRight"
      accessibleName: qsTr("Notifications")
      onClicked: IslandState.toggleWidget("notifications", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("audio")
      name: Audio.muted ? "volume-mute" : "volume"
      tone: Audio.muted ? "muted" : "primary"
      accessibleName: qsTr("Audio")
      onClicked: IslandState.toggleWidget("audio", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("system")
      name: "activity"
      accessibleName: qsTr("System monitor")
      onClicked: IslandState.toggleWidget("system", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("capture")
      name: "camera"
      accessibleName: qsTr("Screen capture")
      onClicked: IslandState.toggleWidget("capture", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("look")
      name: "sparkles"
      accessibleName: qsTr("Appearance")
      onClicked: IslandState.toggleWidget("look", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("clipboard")
      name: "clipboard"
      accessibleName: qsTr("Clipboard")
      onClicked: Cmd.run(["omarchy-shell", "shell", "summon", "omarchy.clipboard"])
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("theme")
      name: "palette"
      accessibleName: qsTr("Theme")
      onClicked: IslandState.toggleWidget("theme", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("settings")
      name: "settings"
      accessibleName: qsTr("Settings")
      onClicked: IslandState.toggleWidget("settings", root.screenName)
    }

    BarIconButton {
      visible: ConfigStore.barItemVisible("power")
      name: "power"
      tone: "danger"
      accessibleName: qsTr("Power")
      onClicked: IslandState.toggleWidget("power", root.screenName)
    }

    BarDivider {
      visible: ConfigStore.barItemVisible("clock")
        || (ConfigStore.barItemVisible("weather") && WeatherData.hasData)
        || (ConfigStore.barItemVisible("battery") && Power.present)
        || (ConfigStore.barItemVisible("visualizer") && vizSlot.visible)
    }

    // ---- Right Status Cluster: Time + Weather + Battery + Audio Visualizer ----
    ClockCluster {
      id: clockCluster
      vertical: root.vertical
      screenName: root.screenName
      visible: ConfigStore.barItemVisible("clock")
    }

    Item {
      id: weatherChip
      visible: ConfigStore.barItemVisible("weather") && WeatherData.hasData
      implicitWidth: root.vertical ? 34 : (weatherGrid.implicitWidth + Tokens.space.xs * 2)
      implicitHeight: root.vertical ? (weatherGrid.implicitHeight + Tokens.space.xs * 2) : Tokens.size.hitMin

      activeFocusOnTab: visible
      Accessible.role: Accessible.Button
      Accessible.name: qsTr("Weather: %1 degrees").arg(WeatherData.w.temp)

      Keys.onSpacePressed: function(e) {
        IslandState.toggleWidget("weather", root.screenName)
        e.accepted = true
      }
      Keys.onReturnPressed: function(e) {
        IslandState.toggleWidget("weather", root.screenName)
        e.accepted = true
      }

      Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.sm
        color: weatherMouse.containsMouse ? Tokens.veilHoverOf(Tokens.surfaceStyle) : "transparent"

        Behavior on color {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          ColorAnimation { duration: Tokens.motion.fast }
        }
      }

      FocusRing {
        active: weatherChip.activeFocus
        ringRadius: Tokens.radius.sm
      }

      Grid {
        id: weatherGrid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        columnSpacing: Tokens.space.xxs
        rowSpacing: 1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Icon {
          name: root.mapWeatherIcon(WeatherData.w.icon)
          size: 14
          tone: "secondary"
        }

        TextLabel {
          role: "sm"
          tone: "primary"
          tabular: true
          font.weight: Font.Medium
          text: WeatherData.w.temp + "°"
        }
      }

      MouseArea {
        id: weatherMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: IslandState.toggleWidget("weather", root.screenName)
      }
    }

    Item {
      id: batteryChip
      visible: ConfigStore.barItemVisible("battery") && Power.present
      implicitWidth: root.vertical ? 34 : (batteryGrid.implicitWidth + Tokens.space.xs * 2)
      implicitHeight: root.vertical ? (batteryGrid.implicitHeight + Tokens.space.xs * 2) : Tokens.size.hitMin

      readonly property string batteryTone: Power.low ? "danger" : (Power.charging ? "success" : "primary")

      activeFocusOnTab: visible
      Accessible.role: Accessible.Button
      Accessible.name: qsTr("Battery %1%").arg(Math.round(Power.level * 100))

      Keys.onSpacePressed: function(e) {
        IslandState.toggleWidget("battery", root.screenName)
        e.accepted = true
      }
      Keys.onReturnPressed: function(e) {
        IslandState.toggleWidget("battery", root.screenName)
        e.accepted = true
      }

      Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.sm
        color: batteryMouse.containsMouse ? Tokens.veilHoverOf(Tokens.surfaceStyle) : "transparent"

        Behavior on color {
          enabled: !Tokens.reducedMotion && !Tokens.gameMode
          ColorAnimation { duration: Tokens.motion.fast }
        }
      }

      FocusRing {
        active: batteryChip.activeFocus
        ringRadius: Tokens.radius.sm
      }

      Grid {
        id: batteryGrid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        columnSpacing: Tokens.space.xxs
        rowSpacing: 1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Icon {
          name: Power.charging ? "battery-charging" : "battery"
          size: 14
          tone: batteryChip.batteryTone
        }

        TextLabel {
          role: "sm"
          tone: batteryChip.batteryTone
          tabular: true
          font.weight: Font.Medium
          text: Math.round(Power.level * 100) + "%"
        }
      }

      MouseArea {
        id: batteryMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: IslandState.toggleWidget("battery", root.screenName)
      }
    }

    AudioVizSlot {
      id: vizSlot
      screenName: root.screenName
      visible: ConfigStore.barItemVisible("visualizer") && implicitWidth > 0.5
    }

    StatusEar {
      screenName: root.screenName
    }
  }
}
