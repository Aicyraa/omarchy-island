.pragma library

// name -> { file, w, h }.
// w/h are only an ESTIMATE used for the first frames of an open (before the widget
// is loaded and can report its real size). Each widget is built on WidgetPanel, whose
// implicitWidth/implicitHeight (content + padding, clamped) is what actually sizes the
// pill; the spring retargets when the real size arrives. Names not listed fall back
// to Placeholder.
var widgets = {
  home: { file: "Home.qml", w: 440, h: 250 },
  wifi: { file: "Wifi.qml", w: 480, h: 300 },
  bluetooth: { file: "Bluetooth.qml", w: 480, h: 220 },
  audio: { file: "Audio.qml", w: 640, h: 260 },
  display: { file: "Display.qml", w: 460, h: 230 },
  battery: { file: "Battery.qml", w: 480, h: 220 },
  calendar: { file: "Calendar.qml", w: 400, h: 330 },
  worldclock: { file: "WorldClock.qml", w: 620, h: 360 },
  power: { file: "Power.qml", w: 600, h: 230 },
  notifications: { file: "Notifications.qml", w: 480, h: 300 },
  system: { file: "System.qml", w: 620, h: 380 },
  tray: { file: "Tray.qml", w: 200, h: 72 },
  theme:         { file: "ThemePicker.qml", w: 720, h: 186 },
  weather: { file: "Weather.qml", w: 440, h: 130 },
  agent: { file: "Agent.qml", w: 600, h: 372 }
}
var fallback = { file: "Placeholder.qml", w: 420, h: 200 }

function entry(name) { return widgets[name] || fallback }
function fileOf(name) { return entry(name).file }
function width(name) { return entry(name).w }
function height(name) { return entry(name).h }
