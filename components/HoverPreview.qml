import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import ".."
import "../services"

// Asymmetric Hero Control Center shown on hover (and pinned as the Home widget):
//   top banner (118 px): edge-to-edge current wallpaper fading into Theme.pill
//   header (44 px): greeting + host, clickable date, and power shortcut (no profile picture)
//   body (248 px):
//     left  (268 px): Hero MediaCard + Volume & Brightness PillSliders
//     right (180 px): staggered bento tiles (icon-disc Wi-Fi/BT, wide+square daily toggles, segmented Saver|Crash)
Item {
  id: root
  property var win: null
  readonly property int pad: Theme.panelPadding
  implicitWidth: 490
  implicitHeight: col.implicitHeight + 2 * pad

  readonly property var players: Mpris.players.values
  function isBridge(p) { return String(p.dbusName || "").indexOf("chromium_audible") >= 0 }
  readonly property var player: {
    var best = null, bestRank = -1
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p.isPlaying && String(p.trackTitle || "") === "") continue
      var rank = (p.isPlaying ? 2 : 0) + (isBridge(p) ? 0 : 1)
      if (rank > bestRank) { best = p; bestRank = rank }
    }
    return best
  }
  function screen() { return win ? win.screenName : "" }

  property string host: ""
  property string bgPath: ""
  Process {
    id: envProc
    running: true
    command: ["bash", "-c", "hostname; readlink -f \"$HOME/.local/state/omarchy/current/background\" 2>/dev/null || true"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        root.host = (lines[0] || "").trim()
        var p = (lines[1] || "").trim()
        root.bgPath = /\.(png|jpe?g|webp|bmp)$/i.test(p) ? ("file://" + p) : ""
      }
    }
  }
  Connections {
    target: Theme
    function onPaletteChanged() { envProc.running = true }
  }
  SystemClock { id: clock; precision: SystemClock.Minutes }
  readonly property string userName: { var u = Quickshell.env("USER") || "user"; return u.charAt(0).toUpperCase() + u.slice(1) }
  readonly property string greeting: { var h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening" }
  readonly property bool hasBg: bgImg.status === Image.Ready
  Component.onCompleted: { Brightness.refresh(); Indicators.refresh() }

  // ---------------- edge-to-edge fading background header ----------------
  ClippingRectangle {
    x: 1; y: 1
    width: root.width - 2; height: 118
    radius: Theme.pillRadius - 1
    color: "transparent"
    z: 0

    Image {
      id: bgImg
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      asynchronous: true; cache: true
      sourceSize.width: 1040; sourceSize.height: 240
      source: root.bgPath
      visible: status === Image.Ready
    }

    Rectangle {
      anchors.fill: parent
      visible: root.hasBg
      gradient: Gradient {
        GradientStop { position: 0.00; color: Theme.pill }
        GradientStop { position: 0.18; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.35) }
        GradientStop { position: 0.42; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.18) }
        GradientStop { position: 0.78; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.88) }
        GradientStop { position: 1.00; color: Theme.pill }
      }
    }

    Rectangle {
      anchors.fill: parent
      visible: root.hasBg
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.00; color: Theme.pill }
        GradientStop { position: 0.16; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.62) }
        GradientStop { position: 0.32; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.08) }
        GradientStop { position: 0.68; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.08) }
        GradientStop { position: 0.84; color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.62) }
        GradientStop { position: 1.00; color: Theme.pill }
      }
    }
  }

  Column {
    id: col
    z: 1
    x: root.pad; y: root.pad; width: root.width - 2 * root.pad; spacing: 12

    // ---------------- slim header strip ----------------
    Item {
      width: parent.width; height: 44

      Column {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 1
        Label {
          text: root.greeting + ", " + root.userName
          color: root.hasBg ? Qt.rgba(1, 1, 1, 0.96) : Theme.text
          font.pixelSize: 16; font.weight: Theme.weightStrong
        }
        Label {
          visible: root.host !== ""
          text: root.host
          color: root.hasBg ? Qt.rgba(1, 1, 1, 0.76) : Theme.textMuted
          font.pixelSize: Theme.typeCaption
        }
      }

      Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
        Item {
          width: dateLbl.implicitWidth + 8; height: 28
          anchors.verticalCenter: parent.verticalCenter
          Label {
            id: dateLbl
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd, MMM d")
            color: dateArea.containsMouse ? (root.hasBg ? Qt.rgba(1, 1, 1, 1) : Theme.text) : (root.hasBg ? Qt.rgba(1, 1, 1, 0.80) : Theme.textMuted)
            font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel
            Behavior on color { ColorAnimation { duration: 120 } }
          }
          MouseArea {
            id: dateArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: IslandState.openWidget("calendar", root.screen())
          }
        }
        SmoothRect {
          width: 1; height: 12; radius: 0.5
          color: root.hasBg ? Qt.rgba(1, 1, 1, 0.24) : Theme.pillBorder
          anchors.verticalCenter: parent.verticalCenter
        }
        Item {
          width: 28; height: 28
          anchors.verticalCenter: parent.verticalCenter
          SmoothRect {
            anchors.fill: parent; radius: 14
            color: root.hasBg ? Qt.rgba(1, 1, 1, 0.14) : Theme.surface
            opacity: powerArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
          }
          Icon {
            anchors.centerIn: parent; name: "power"; size: Theme.iconSm
            color: powerArea.containsMouse ? Theme.dangerInk : (root.hasBg ? Qt.rgba(1, 1, 1, 0.85) : Theme.textMuted)
            Behavior on color { ColorAnimation { duration: 120 } }
          }
          MouseArea {
            id: powerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: IslandState.openWidget("power", root.screen())
          }
        }
      }
    }

    // ---------------- asymmetric two-column body ----------------
    Row {
      id: body
      width: parent.width; spacing: 10
      readonly property int leftW: 268
      readonly property int rightW: width - leftW - spacing

      // ---- left focal column: hero media card + volume & brightness sliders ----
      Column {
        id: leftCol
        width: body.leftW; spacing: Theme.s8

        MediaCard {
          id: media
          width: parent.width
          height: Math.max(144, rightCol.implicitHeight - sliders.implicitHeight - Theme.s8)
          p: root.player
        }
        Column {
          id: sliders
          width: parent.width; spacing: Theme.s8
          PillSlider {
            width: parent.width
            icon: "volume"
            iconItem: VolumeIcon { level: Audio.volume; muted: Audio.muted; size: Theme.iconMd; color: Theme.accentText }
            value: Audio.muted ? 0 : Audio.volume
            maxValue: 1.5
            onMoved: function (v) { Audio.setVolume(v) }
          }
          PillSlider {
            visible: Brightness.available
            width: parent.width
            icon: "sun"; value: Brightness.level
            onMoved: function (v) { Brightness.set(v) }
          }
        }
      }

      // ---- right supporting column: icon-disc hierarchy + staggered bento layout ----
      Column {
        id: rightCol
        width: body.rightW; spacing: Theme.s8

        component ConnectivityCard: Item {
          id: cc
          property string icon: ""
          property bool liveWifi: false
          property bool on: false
          property bool connected: false
          property string line1: ""
          property string line2: ""
          property string badge: ""
          signal toggled()
          signal opened()
          height: 78
          readonly property color baseFill: on ? Theme.mix(Theme.surface, Theme.accentFill, 0.14) : Theme.surface
          readonly property color iconFg: on ? Theme.accentText : Theme.textMuted
          SmoothRect {
            anchors.fill: parent; radius: Theme.tileRadius
            color: ccArea.pressed ? Qt.lighter(cc.baseFill, 1.14) : (ccArea.containsMouse ? Qt.lighter(cc.baseFill, 1.07) : cc.baseFill)
            borderWidth: 1
            borderColor: cc.on ? Qt.rgba(Theme.accentInk.r, Theme.accentInk.g, Theme.accentInk.b, 0.32) : Theme.pillBorder
            Behavior on color { ColorAnimation { duration: 140 } }
          }
          Item {
            x: 9; y: 10; width: parent.width - 18; height: 28
            SmoothRect {
              width: 28; height: 28; radius: 14
              color: cc.on ? Theme.accentFill : Theme.surfaceRaised
              Behavior on color { ColorAnimation { duration: 140 } }
              WifiIcon {
                visible: cc.liveWifi; anchors.centerIn: parent
                size: 15; strokeWidth: 2.0; off: !Net.enabled; level: Net.connected ? Net.strength : 0; color: cc.iconFg
              }
              Icon { visible: !cc.liveWifi; anchors.centerIn: parent; name: cc.icon; size: 15; color: cc.iconFg }
            }
            Label {
              visible: cc.badge !== ""
              anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
              mono: true; text: cc.badge; color: cc.on ? Theme.accentInk : Theme.textMuted; font.pixelSize: 10
            }
          }
          Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 9; rightMargin: 9; bottomMargin: 9 }
            spacing: 1
            Label { width: parent.width; elide: Text.ElideRight; text: cc.line1; color: Theme.text; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
            Row {
              width: parent.width; spacing: 4
              SmoothRect { visible: cc.on; width: 5; height: 5; radius: 2.5; anchors.verticalCenter: parent.verticalCenter
                color: cc.connected ? Theme.successInk : Theme.accentInk }
              Label { width: parent.width - (cc.on ? 9 : 0); elide: Text.ElideRight; text: cc.line2; color: Theme.textMuted; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            }
          }
          MouseArea {
            id: ccArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (m) { if (m.button === Qt.RightButton) cc.opened(); else cc.toggled() }
          }
        }

        component DailyTile: Item {
          id: dt
          property string icon: ""
          property string label: ""
          property string stateText: on ? "On" : "Off"
          property bool on: false
          property bool compact: false
          signal toggled()
          signal opened()
          height: Theme.tileHeight
          readonly property color baseFill: on ? Theme.mix(Theme.surface, Theme.accentFill, 0.14) : Theme.surface
          SmoothRect {
            anchors.fill: parent; radius: Theme.tileRadius
            color: dtArea.pressed ? Qt.lighter(dt.baseFill, 1.14) : (dtArea.containsMouse ? Qt.lighter(dt.baseFill, 1.07) : dt.baseFill)
            borderWidth: 1
            borderColor: dt.on ? Qt.rgba(Theme.accentInk.r, Theme.accentInk.g, Theme.accentInk.b, 0.32) : Theme.pillBorder
            Behavior on color { ColorAnimation { duration: 140 } }
          }
          // Wide form: left circular icon disc + stacked label & status
          Item {
            visible: !dt.compact
            anchors.fill: parent
            SmoothRect {
              x: 9; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 14
              color: dt.on ? Theme.accentFill : Theme.surfaceRaised
              Behavior on color { ColorAnimation { duration: 140 } }
              Icon { anchors.centerIn: parent; name: dt.icon; size: 14; color: dt.on ? Theme.accentText : Theme.text }
            }
            Column {
              anchors { left: parent.left; right: parent.right; leftMargin: 44; rightMargin: 8; verticalCenter: parent.verticalCenter }
              spacing: 1
              Label { width: parent.width; elide: Text.ElideRight; text: dt.label; color: Theme.text; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
              Label { width: parent.width; elide: Text.ElideRight; text: dt.stateText; color: dt.on ? Theme.accentInk : Theme.textMuted; font.pixelSize: 10 }
            }
          }
          // Compact square form: centered icon disc over label + corner status dot
          Item {
            visible: dt.compact
            anchors.fill: parent
            SmoothRect {
              visible: dt.on
              anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 7; anchors.rightMargin: 7
              width: 5; height: 5; radius: 2.5; color: Theme.accentInk
            }
            Column {
              anchors.centerIn: parent; spacing: 3
              SmoothRect {
                anchors.horizontalCenter: parent.horizontalCenter; width: 26; height: 26; radius: 13
                color: dt.on ? Theme.accentFill : Theme.surfaceRaised
                Behavior on color { ColorAnimation { duration: 140 } }
                Icon { anchors.centerIn: parent; name: dt.icon; size: 13; color: dt.on ? Theme.accentText : Theme.text }
              }
              Label { anchors.horizontalCenter: parent.horizontalCenter; text: dt.label; color: Theme.text; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
            }
          }
          MouseArea {
            id: dtArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (m) { if (m.button === Qt.RightButton) dt.opened(); else dt.toggled() }
          }
        }

        component SegChip: Item {
          id: sc
          property string icon: ""
          property string label: ""
          property bool on: false
          signal toggled()
          height: parent.height
          SmoothRect {
            anchors.fill: parent; anchors.margins: 3; radius: height / 2
            color: sc.on ? Theme.mix(Theme.surfaceRaised, Theme.accentFill, 0.24)
                 : (scArea.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08) : "transparent")
            Behavior on color { ColorAnimation { duration: 140 } }
          }
          Row {
            anchors.centerIn: parent; spacing: 5
            SmoothRect { visible: sc.on; width: 5; height: 5; radius: 2.5; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
            Icon { anchors.verticalCenter: parent.verticalCenter; name: sc.icon; size: 13; color: sc.on ? Theme.accentInk : Theme.textMuted }
            Label { anchors.verticalCenter: parent.verticalCenter; text: sc.label; color: sc.on ? Theme.text : Theme.textMuted; font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
          }
          MouseArea {
            id: scArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: sc.toggled()
          }
        }

        // Row 1: Asymmetrical Connectivity (56% Wi-Fi / 44% Bluetooth)
        Row {
          id: connRow
          width: parent.width; spacing: Theme.s8
          visible: Net.hasWifi || Bt.hasAdapter
          readonly property int count: (Net.hasWifi ? 1 : 0) + (Bt.hasAdapter ? 1 : 0)
          readonly property int wifiW: count === 1 ? width : Math.round((width - Theme.s8) * 0.56)
          readonly property int btW: count === 1 ? width : (width - Theme.s8 - wifiW)

          ConnectivityCard {
            width: connRow.wifiW; visible: Net.hasWifi; liveWifi: true
            icon: Net.enabled ? "wifi" : "wifi-off"; on: Net.enabled; connected: Net.connected
            line1: Net.enabled && Net.connected ? Net.ssid : "Wi-Fi"
            line2: !Net.enabled ? "Off" : (Net.connected ? "Connected" : "Ready")
            badge: Net.enabled && Net.connected ? Math.round(Net.strength * 100) + "%" : ""
            onToggled: Net.toggle(); onOpened: IslandState.openWidget("wifi", root.screen())
          }
          ConnectivityCard {
            width: connRow.btW; visible: Bt.hasAdapter
            icon: "bluetooth"; on: Bt.enabled
            readonly property var dev: Bt.connectedDevices.length > 0 ? Bt.connectedDevices[0] : null
            connected: dev !== null
            line1: Bt.enabled && dev ? Bt.connectedName : "Bluetooth"
            line2: !Bt.enabled ? "Off" : (dev ? "Connected" : Bt.sorted.length + " paired")
            badge: Bt.enabled && dev && dev.batteryAvailable ? Math.round(dev.battery * 100) + "%" : ""
            onToggled: Bt.toggle(); onOpened: IslandState.openWidget("bluetooth", root.screen())
          }
        }

        // Rows 2 & 3: Staggered Bento Daily Toggles (58%/42% then 42%/58%)
        Column {
          id: dailyGrid
          width: parent.width; spacing: Theme.s8
          readonly property int wideW: Math.round((width - Theme.s8) * 0.58)
          readonly property int sqW: width - Theme.s8 - wideW
          Row {
            width: parent.width; spacing: Theme.s8
            DailyTile {
              width: dailyGrid.wideW; label: "Focus"; icon: Indicators.dnd ? "bell-off" : "bell"; on: Indicators.dnd
              onToggled: Indicators.toggleDnd(); onOpened: IslandState.openWidget("notifications", root.screen())
            }
            DailyTile {
              width: dailyGrid.sqW; compact: true; label: "Night"; icon: "moon"; on: Indicators.nightLight
              onToggled: Indicators.toggleNightLight(); onOpened: IslandState.openWidget("display", root.screen())
            }
          }
          Row {
            width: parent.width; spacing: Theme.s8
            DailyTile {
              width: Indicators.dictationAvailable ? dailyGrid.sqW : parent.width
              compact: Indicators.dictationAvailable
              label: "Awake"; icon: "coffee"; on: Indicators.stayAwake
              onToggled: Indicators.toggleStayAwake(); onOpened: IslandState.openWidget("battery", root.screen())
            }
            DailyTile {
              visible: Indicators.dictationAvailable
              width: dailyGrid.wideW; label: "Dictate"; icon: "mic-dictate"; on: Indicators.dictation !== "idle"
              stateText: Indicators.dictation !== "idle" ? "Live" : "Off"
              onToggled: Indicators.toggleDictation()
            }
          }
        }

        // Row 4: Unified segmented utility bar (Saver | Crash)
        SmoothRect {
          width: parent.width; height: 34; radius: 17
          color: Theme.surface; borderWidth: 1; borderColor: Theme.pillBorder
          Row {
            anchors.fill: parent
            readonly property real segW: (width - 1) / 2
            SegChip { width: parent.segW; label: "Saver"; icon: "eye"; on: Indicators.screensaver; onToggled: Indicators.toggleScreensaver() }
            SmoothRect { width: 1; height: 14; radius: 0.5; color: Theme.pillBorder; anchors.verticalCenter: parent.verticalCenter }
            SegChip { width: parent.segW; label: "Crash"; icon: "alert"; on: Indicators.crashCapture; onToggled: Indicators.toggleCrashCapture() }
          }
        }
      }
    }
  }
}
