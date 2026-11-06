import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import ".."
import "../services"

// What the pill shows on hover: a preview of the essentials.
//   profile header (current wallpaper as its background) · quick toggles (no names, one info line) · volume + brightness · media player.
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
      MouseArea { anchors.fill: parent; onClicked: IslandState.openWidget("calendar", root.screen()) }
    }

    // ---------------- quick toggles ----------------
    Row {
      id: toggles
      width: parent.width; spacing: Theme.s8
      readonly property var items: [
        { icon: Net.enabled ? "wifi" : "wifi-off", title: "Wi-Fi", show: Net.hasWifi, on: Net.enabled,
          sub: !Net.enabled ? "Off" : (Net.connected ? Net.ssid : "Not connected"), toggle: function () { Net.toggle() }, open: "wifi" },
        { icon: "bluetooth", title: "Bluetooth", show: Bt.hasAdapter, on: Bt.enabled,
          sub: !Bt.enabled ? "Off" : (Bt.connectedName !== "" ? Bt.connectedName : "On"), toggle: function () { Bt.toggle() }, open: "bluetooth" },
        { icon: Indicators.dnd ? "bell-off" : "bell", title: "Focus", show: true, on: Indicators.dnd,
          sub: Indicators.dnd ? "On" : (Notifs.liveCount > 0 ? Notifs.liveCount + " new" : "Off"), toggle: function () { Indicators.toggleDnd() }, open: "notifications" },
        { icon: "moon", title: "Night light", show: true, on: Indicators.nightLight,
          sub: Indicators.nightLight ? "On" : "Off", toggle: function () { Indicators.toggleNightLight() }, open: "display" },
        { icon: "coffee", title: "Awake", show: true, on: Indicators.stayAwake,
          sub: Indicators.stayAwake ? "On" : "Off", toggle: function () { Indicators.toggleStayAwake() }, open: "battery" },
        { icon: "mic-dictate", title: "Dictation", show: Indicators.dictationAvailable, on: Indicators.dictation !== "idle",
          sub: Indicators.dictation === "idle" ? "Off" : Indicators.dictation, toggle: function () { Indicators.toggleDictation() }, open: "" }
      ]
      readonly property int count: Math.max(1, items.filter(function (t) { return t.show }).length)
      Repeater {
        model: toggles.items
        delegate: Rectangle {
          required property var modelData
          visible: modelData.show
          width: (toggles.width - (toggles.count - 1) * Theme.s8) / toggles.count; height: 60; radius: Theme.tileRadius
          color: modelData.on ? Theme.accentFill : Theme.surface
          Behavior on color { ColorAnimation { duration: 150 } }
          // No names: the icon says what it is; the line under it says what it is doing or connected to.
          Column {
            anchors.centerIn: parent; width: parent.width - 10; spacing: 4
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.icon; size: Theme.iconMd
              color: modelData.on ? Theme.accentText : Theme.text }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; textFormat: Text.PlainText
              text: modelData.sub; color: modelData.on ? Theme.textOnAccentMuted : Theme.textMuted; font.pixelSize: 10; font.weight: Theme.weightLabel }
          }
          MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (m) { if (m.button === Qt.RightButton) { if (modelData.open !== "") IslandState.openWidget(modelData.open, root.screen()) } else modelData.toggle() } }
        }
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
