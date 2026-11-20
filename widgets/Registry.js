.pragma library

// name -> { file, w, h }.
// w/h are only an ESTIMATE used for the first frames of an open (before the widget
// is loaded and can report its real size). Each widget is built on WidgetPanel, whose
// implicitWidth/implicitHeight (content + padding, clamped) is what actually sizes the
// pill; the spring retargets when the real size arrives. Names not listed fall back
// to Placeholder.
var widgets = {
  home:          { file: "Home.qml", w: 440, h: 374 },
  wifi:          { file: "Wifi.qml", w: 500, h: 320 },
  bluetooth:     { file: "Bluetooth.qml", w: 520, h: 240 },
  audio:         { file: "Audio.qml", w: 660, h: 280 },
  display:       { file: "Display.qml", w: 540, h: 290 },
  battery:       { file: "Battery.qml", w: 540, h: 210 },
  calendar:      { file: "Calendar.qml", w: 590, h: 320 },
  worldclock:    { file: "WorldClock.qml", w: 660, h: 340 },
  power:         { file: "Power.qml", w: 668, h: 128 },
  notifications: { file: "Notifications.qml", w: 500, h: 360 },
  system:        { file: "System.qml", w: 620, h: 420 },
  tray:          { file: "Tray.qml", w: 200, h: 48 },
  theme:         { file: "ThemePicker.qml", w: 720, h: 210 },
  look:          { file: "Look.qml", w: 640, h: 420 },
  weather:       { file: "Weather.qml", w: 440, h: 190 },
  agent:         { file: "Agent.qml", w: 620, h: 340 },
  menu:          { file: "Menu.qml", w: 720, h: 454 }
}
var fallback = { file: "Placeholder.qml", w: 420, h: 200 }

function entry(name) { return widgets[name] || fallback }
function fileOf(name) { return entry(name).file }
function width(name) { return entry(name).w }
function height(name) { return entry(name).h }
