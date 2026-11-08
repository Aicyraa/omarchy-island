.pragma library

// name -> { file, w, h }.
// w/h are only an ESTIMATE used for the first frames of an open (before the widget
// is loaded and can report its real size). Each widget is built on WidgetPanel, whose
// implicitWidth/implicitHeight (content + padding, clamped) is what actually sizes the
// pill; the spring retargets when the real size arrives. Names not listed fall back
// to Placeholder.
var widgets = {
  home: { file: "Home.qml", w: 440, h: 284 },
  wifi: { file: "Wifi.qml", w: 480, h: 364 },
  bluetooth: { file: "Bluetooth.qml", w: 480, h: 149 },
  audio: { file: "Audio.qml", w: 640, h: 278 },
  display: { file: "Display.qml", w: 460, h: 416 },
  battery: { file: "Battery.qml", w: 480, h: 172 },
  calendar: { file: "Calendar.qml", w: 400, h: 348 },
  worldclock: { file: "WorldClock.qml", w: 620, h: 340 },
  power: { file: "Power.qml", w: 660, h: 276 },
  notifications: { file: "Notifications.qml", w: 480, h: 420 },
  system: { file: "System.qml", w: 620, h: 420 },
  tray: { file: "Tray.qml", w: 200, h: 48 },
  theme:         { file: "ThemePicker.qml", w: 720, h: 203 },
  weather: { file: "Weather.qml", w: 440, h: 190 },
  agent: { file: "Agent.qml", w: 600, h: 372 },
  menu: { file: "Menu.qml", w: 720, h: 380 }
}
var fallback = { file: "Placeholder.qml", w: 420, h: 200 }

function entry(name) { return widgets[name] || fallback }
function fileOf(name) { return entry(name).file }
function width(name) { return entry(name).w }
function height(name) { return entry(name).h }
