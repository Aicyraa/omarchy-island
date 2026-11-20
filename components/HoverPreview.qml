import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import ".."
import "../services"

// What the pill shows on hover (and the Home widget, which is the same form pinned): a preview of the essentials.
//   profile header (current wallpaper as its background)
//   body, two columns:
//     left  (narrow): Wi-Fi and Bluetooth tiles with live details, then the six icon toggles as a 3 x 2 grid
//     right (wide):   the media card (always shown: a placeholder when nothing plays), then volume and brightness
// Everything is live and clickable; right-click on a toggle opens its full widget. The pill sizes itself from
// implicitWidth/implicitHeight. Height: 16 + 84 (header) + 10 + 248 (body) + 16 = 374, the fallback in Island.qml.
Item {
  id: root
  property var win: null
  readonly property int pad: Theme.panelPadding
  implicitWidth: 440
  implicitHeight: col.implicitHeight + 2 * pad

  readonly property var players: Mpris.players.values
  // Priority: a playing player beats a paused one; any other player beats the Chromium audible-tab bridge
  // (so a real media app is never hidden by a background tab that is only making sound).
  function isBridge(p) { return String(p.dbusName || "").indexOf("chromium_audible") >= 0 }
  readonly property var player: {
    var best = null, bestRank = -1
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p.isPlaying && String(p.trackTitle || "") === "") continue   // an idle browser is not worth a card
      var rank = (p.isPlaying ? 2 : 0) + (isBridge(p) ? 0 : 1)
      if (rank > bestRank) { best = p; bestRank = rank }
    }
    return best
  }
  function screen() { return win ? win.screenName : "" }

  // ---- profile data (read once per hover) ----
  property string host: ""
  Process {
    running: true
    command: ["hostname"]
    stdout: StdioCollector { onStreamFinished: root.host = text.trim() }
  }
  SystemClock { id: clock; precision: SystemClock.Minutes }
  readonly property string userName: { var u = Quickshell.env("USER") || "user"; return u.charAt(0).toUpperCase() + u.slice(1) }
  readonly property string greeting: { var h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening" }
  Component.onCompleted: { Brightness.refresh(); Indicators.refresh() }

  Column {
    id: col
    x: root.pad; y: root.pad; width: root.width - 2 * root.pad; spacing: 10

    // ---------------- profile header ----------------
    ClippingRectangle {
      width: parent.width; height: 84; radius: Theme.tileRadius; color: Theme.surface
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
        Text { textFormat: Text.PlainText; text: root.greeting; color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: Theme.typeLabel }
        Text { textFormat: Text.PlainText; text: root.userName; color: Qt.rgba(1, 1, 1, 0.98); font.pixelSize: 18; font.weight: Theme.weightStrong }
        Text { textFormat: Text.PlainText; text: root.host; color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: Theme.typeLabel }
      }
      Column {
        anchors.right: parent.right; anchors.rightMargin: Theme.s16; anchors.verticalCenter: parent.verticalCenter; spacing: 1
        Text { anchors.right: parent.right; textFormat: Text.PlainText; text: Qt.formatDateTime(clock.date, "HH:mm")
          color: Qt.rgba(1, 1, 1, 0.98); font.pixelSize: 24; font.weight: Theme.weightStrong }
        Text { anchors.right: parent.right; textFormat: Text.PlainText; text: Qt.formatDateTime(clock.date, "ddd, MMM d")
          color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: Theme.typeLabel }
        Text { anchors.right: parent.right; visible: Power.present; textFormat: Text.PlainText
          text: Math.round(Power.level * 100) + "%" + (Power.charging ? " · charging" : ""); color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: Theme.typeLabel }
      }
      MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: IslandState.openWidget("calendar", root.screen()) }
    }

    // ---------------- body: two columns ----------------
    Row {
      id: body
      width: parent.width; spacing: Theme.s8
      readonly property int tile: 56                              // every tile is 56 px: the wide tiles, the squares, the media slot
      readonly property int leftW: 3 * tile + 2 * Theme.s8        // three squares across, so the wide tiles match the grid

      // ---- left: Wi-Fi, Bluetooth, then the six icon toggles ----
      Column {
        id: leftCol
        width: body.leftW; spacing: Theme.s8

        // Wide tile: an icon disc, a name and a detail line. Also used for the 56 px squares (icon + label).
        component QuickTile: Rectangle {
          id: qt
          property string icon; property bool on: false; property bool wide: false
          property string line1; property string line2
          property string label: ""        // a name under an icon-only tile
          signal toggled(); signal opened()
          radius: Theme.tileRadius; height: body.tile
          color: area.pressed ? Qt.lighter(fill, 1.18) : (area.containsMouse ? Qt.lighter(fill, 1.09) : fill)
          readonly property color fill: on ? Theme.accentFill : Theme.surface
          Behavior on color { ColorAnimation { duration: 140 } }
          readonly property color fg: on ? Theme.accentText : Theme.text
          readonly property color fgMuted: on ? Theme.textOnAccentMuted : Theme.textMuted
          Rectangle {                                          // icon disc (wide tiles)
            visible: qt.wide; x: Theme.s8 + 2; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 15
            color: qt.on ? Qt.rgba(1, 1, 1, 0.16) : Theme.mix(Theme.surface, Theme.text, 0.10)
            Icon { anchors.centerIn: parent; name: qt.icon; size: Theme.iconSm; color: qt.fg } }
          Icon { visible: !qt.wide; anchors.horizontalCenter: parent.horizontalCenter
            y: qt.label !== "" ? 10 : (qt.height - height) / 2; name: qt.icon; size: Theme.iconLg - 2; color: qt.fg }
          Text { visible: !qt.wide && qt.label !== ""; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
            anchors.bottomMargin: 7; textFormat: Text.PlainText; text: qt.label; color: qt.fg
            font.pixelSize: Theme.typeCaption; font.weight: Theme.weightLabel }
          Column {
            visible: qt.wide
            anchors.left: parent.left; anchors.leftMargin: Theme.s8 + 2 + 30 + Theme.s8 + 2; anchors.right: parent.right; anchors.rightMargin: Theme.s8
            anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: qt.line1
              color: qt.fg; font.pixelSize: Theme.typeLabel; font.weight: Theme.weightLabel }
            Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: qt.line2
              color: qt.fgMuted; font.pixelSize: Theme.typeCaption - 1 }
          }
          MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (m) { if (m.button === Qt.RightButton) qt.opened(); else qt.toggled() } }
        }

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

        Grid {
          columns: 3; spacing: Theme.s8; width: parent.width
          QuickTile { width: body.tile; label: "Focus"; icon: Indicators.dnd ? "bell-off" : "bell"; on: Indicators.dnd
            onToggled: Indicators.toggleDnd(); onOpened: IslandState.openWidget("notifications", root.screen()) }
          QuickTile { width: body.tile; label: "Night"; icon: "moon"; on: Indicators.nightLight
            onToggled: Indicators.toggleNightLight(); onOpened: IslandState.openWidget("display", root.screen()) }
          QuickTile { width: body.tile; label: "Awake"; icon: "coffee"; on: Indicators.stayAwake
            onToggled: Indicators.toggleStayAwake(); onOpened: IslandState.openWidget("battery", root.screen()) }
          QuickTile { width: body.tile; label: "Dictate"; icon: "mic-dictate"; on: Indicators.dictation !== "idle"; visible: Indicators.dictationAvailable
            onToggled: Indicators.toggleDictation() }
          // Trigger > Toggle in the menu had these two as well (the menu section is hidden in favour of this form).
          QuickTile { width: body.tile; label: "Saver"; icon: "eye"; on: Indicators.screensaver
            onToggled: Indicators.toggleScreensaver() }
          QuickTile { width: body.tile; label: "Crash"; icon: "alert"; on: Indicators.crashCapture
            onToggled: Indicators.toggleCrashCapture() }
        }
      }

      // ---- right: the media card, then volume and brightness ----
      Column {
        id: rightCol
        width: parent.width - body.leftW - Theme.s8
        height: leftCol.implicitHeight
        spacing: Theme.s8

        MediaCard {
          id: media
          width: parent.width
          height: rightCol.height - sliders.height - Theme.s8   // fills the column beside the left stack
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
    }
  }
}
