import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import ".."
import "../services"

// What the pill shows on hover: a preview of the essentials.
//   profile header (current wallpaper as its background) · Wi-Fi and Bluetooth tiles with live details beside a 2x2 grid
//   of icon toggles · volume + brightness · media player.
// Everything is live and clickable; right-click on a toggle opens its full widget. The media card only
// takes space while a player exists. The pill sizes itself from implicitWidth/implicitHeight.
Item {
  id: root
  property var win: null
  readonly property int pad: Theme.panelPadding
  implicitWidth: 440
  implicitHeight: col.implicitHeight + 2 * pad

  readonly property var players: Mpris.players.values
  readonly property var player: {
    for (var i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
    for (var j = 0; j < players.length; j++) if (String(players[j].trackTitle || "") !== "") return players[j]
    return null                               // an idle browser with no track is not worth a card
  }
  function screen() { return win ? win.screenName : "" }

  // ---- profile data (read once per hover) ----
  property string host: ""
  property string uptime: ""
  Process {
    running: true
    command: ["bash", "-c", "hostname; uptime -p | sed 's/^up //; s/ days\\?/d/; s/ hours\\?/h/; s/ minutes\\?/m/; s/,//g'"]
    stdout: StdioCollector { onStreamFinished: { var l = text.split("\n"); root.host = l[0] || ""; root.uptime = l[1] || "" } }
  }
  SystemClock { id: clock; precision: SystemClock.Minutes }
  readonly property string userName: { var u = Quickshell.env("USER") || "user"; return u.charAt(0).toUpperCase() + u.slice(1) }
  readonly property string greeting: { var h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening" }
  Component.onCompleted: { Brightness.refresh(); Indicators.refresh() }

  Column {
    id: col
    x: root.pad; y: root.pad; width: root.width - 2 * root.pad; spacing: Theme.s12

    // ---------------- profile header ----------------
    ClippingRectangle {
      width: parent.width; height: 88; radius: Theme.tileRadius; color: Theme.surface
      Image {
        anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
        sourceSize.width: 960; sourceSize.height: 400
        source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
      }
      Rectangle { anchors.fill: parent                              // keeps the text readable on any wallpaper
        gradient: Gradient { orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.66) }
          GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.22) } } }
      ClippingRectangle {
        id: avatar
        x: Theme.s16; anchors.verticalCenter: parent.verticalCenter
        width: 52; height: 52; radius: 26; color: Theme.accentFill
        border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.85)
        Image { id: face; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
          source: "file://" + Quickshell.env("HOME") + "/.face"; sourceSize.width: 104; sourceSize.height: 104 }
        Text { anchors.centerIn: parent; visible: face.status !== Image.Ready; textFormat: Text.PlainText
          text: root.userName.charAt(0); color: Theme.accentText; font.pixelSize: 22; font.weight: Theme.weightStrong }
      }
      Column {
        anchors.left: avatar.right; anchors.leftMargin: Theme.s12; anchors.verticalCenter: parent.verticalCenter; spacing: 2
        Text { textFormat: Text.PlainText; text: root.greeting; color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: 11 }
        Text { textFormat: Text.PlainText; text: root.userName; color: Qt.rgba(1, 1, 1, 0.98); font.pixelSize: 18; font.weight: Theme.weightStrong }
        Text { textFormat: Text.PlainText; text: root.host + (root.uptime !== "" ? " · up " + root.uptime : ""); color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: 11 }
      }
      Column {
        anchors.right: parent.right; anchors.rightMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 1
        Text { anchors.right: parent.right; textFormat: Text.PlainText; text: Qt.formatDateTime(clock.date, "HH:mm")
          color: Qt.rgba(1, 1, 1, 0.98); font.pixelSize: 24; font.weight: Theme.weightStrong }
        Text { anchors.right: parent.right; textFormat: Text.PlainText; text: Qt.formatDateTime(clock.date, "ddd, MMM d")
          color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: 11 }
        Text { anchors.right: parent.right; visible: Power.present; textFormat: Text.PlainText
          text: Math.round(Power.level * 100) + "%" + (Power.charging ? " · charging" : ""); color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: 11 }
      }
      MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: IslandState.openWidget("calendar", root.screen()) }
    }

    // ---------------- quick toggles ----------------
    // Left: Wi-Fi and Bluetooth as wide tiles with live details. Right: the other toggles as a 2x2 grid of icons.
    component QuickTile: Rectangle {
      id: qt
      property string icon; property bool on: false; property bool wide: false
      property string line1; property string line2
      signal toggled(); signal opened()
      radius: Theme.tileRadius; height: 52
      color: area.pressed ? Qt.lighter(fill, 1.18) : (area.containsMouse ? Qt.lighter(fill, 1.09) : fill)
      readonly property color fill: on ? Theme.accentFill : Theme.surface
      Behavior on color { ColorAnimation { duration: 140 } }
      readonly property color fg: on ? Theme.accentText : Theme.text
      readonly property color fgMuted: on ? Theme.textOnAccentMuted : Theme.textMuted
      Rectangle {                                          // icon disc (wide tiles)
        visible: qt.wide; x: Theme.s8 + 2; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; radius: 17
        color: qt.on ? Qt.rgba(1, 1, 1, 0.16) : Theme.mix(Theme.surface, Theme.text, 0.10)
        Icon { anchors.centerIn: parent; name: qt.icon; size: Theme.iconMd; color: qt.fg } }
      Icon { visible: !qt.wide; anchors.centerIn: parent; name: qt.icon; size: Theme.iconLg - 2; color: qt.fg }
      Column {
        visible: qt.wide
        anchors.left: parent.left; anchors.leftMargin: Theme.s8 + 2 + 34 + Theme.s12; anchors.right: parent.right; anchors.rightMargin: Theme.s12
        anchors.verticalCenter: parent.verticalCenter; spacing: 1
        Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: qt.line1
          color: qt.fg; font.pixelSize: 13; font.weight: Theme.weightLabel }
        Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: qt.line2
          color: qt.fgMuted; font.pixelSize: 11 }
      }
      MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (m) { if (m.button === Qt.RightButton) qt.opened(); else qt.toggled() } }
    }

    Row {
      id: toggles
      width: parent.width; spacing: Theme.s8
      readonly property real gridW: 2 * 52 + Theme.s8

      Column {
        width: toggles.width - toggles.gridW - Theme.s8; spacing: Theme.s8
        QuickTile {
          width: parent.width; wide: true; visible: Net.hasWifi
          icon: Net.enabled ? "wifi" : "wifi-off"; on: Net.enabled
          line1: !Net.enabled ? "Wi-Fi off" : (Net.connected ? Net.ssid : "Not connected")
          line2: !Net.enabled ? "Tap to turn on" : (Net.connected
                   ? (Net.strength > 0.75 ? "Excellent" : Net.strength > 0.5 ? "Good" : Net.strength > 0.25 ? "Fair" : "Weak") + " · " + Math.round(Net.strength * 100) + "%"
                   : "Choose a network")
          onToggled: Net.toggle(); onOpened: IslandState.openWidget("wifi", root.screen())
        }
        QuickTile {
          width: parent.width; wide: true; visible: Bt.hasAdapter
          icon: "bluetooth"; on: Bt.enabled
          readonly property var dev: Bt.connectedDevices.length > 0 ? Bt.connectedDevices[0] : null
          line1: !Bt.enabled ? "Bluetooth off" : (dev ? Bt.connectedName : "No device connected")
          line2: !Bt.enabled ? "Tap to turn on" : (dev
                   ? (dev.batteryAvailable ? Math.round(dev.battery * 100) + "% battery" : "Connected") + (Bt.connectedDevices.length > 1 ? " · +" + (Bt.connectedDevices.length - 1) + " more" : "")
                   : Bt.sorted.length + " paired")
          onToggled: Bt.toggle(); onOpened: IslandState.openWidget("bluetooth", root.screen())
        }
      }
      Grid {
        columns: 2; spacing: Theme.s8; width: toggles.gridW
        QuickTile { width: 52; icon: Indicators.dnd ? "bell-off" : "bell"; on: Indicators.dnd
          onToggled: Indicators.toggleDnd(); onOpened: IslandState.openWidget("notifications", root.screen()) }
        QuickTile { width: 52; icon: "moon"; on: Indicators.nightLight
          onToggled: Indicators.toggleNightLight(); onOpened: IslandState.openWidget("display", root.screen()) }
        QuickTile { width: 52; icon: "coffee"; on: Indicators.stayAwake
          onToggled: Indicators.toggleStayAwake(); onOpened: IslandState.openWidget("battery", root.screen()) }
        QuickTile { width: 52; icon: "mic-dictate"; on: Indicators.dictation !== "idle"; visible: Indicators.dictationAvailable
          onToggled: Indicators.toggleDictation() }
      }
    }

    // ---------------- volume + brightness ----------------
    Row {
      width: parent.width; spacing: Theme.s8
      PillSlider {
        width: Brightness.available ? (parent.width - Theme.s8) / 2 : parent.width
        icon: "volume"
        iconItem: VolumeIcon { level: Audio.volume; muted: Audio.muted; size: Theme.iconMd; color: Theme.accentText }
        value: Audio.muted ? 0 : Audio.volume
        onMoved: function (v) { Audio.setVolume(v) }
      }
      PillSlider {
        visible: Brightness.available
        width: (parent.width - Theme.s8) / 2
        icon: "sun"; value: Brightness.level
        onMoved: function (v) { Brightness.set(v) }
      }
    }

    // ---------------- media ----------------
    MediaCard { width: parent.width; visible: root.player !== null; p: root.player }
  }
}
