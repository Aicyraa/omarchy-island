.pragma library

// name -> { file, w, h }.
// w/h are estimates used on the first frames before the widget reports its implicit size.
var widgets = {
  settings:      { file: "Settings.qml", w: 620, h: 430 },
  home:          { file: "Settings.qml", w: 620, h: 430 },
  media:         { file: "Media.qml", w: 480, h: 255 },
  capture:       { file: "Capture.qml", w: 480, h: 300 },
  wifi:          { file: "Wifi.qml", w: 500, h: 340 },
  bluetooth:     { file: "Bluetooth.qml", w: 520, h: 280 },
  audio:         { file: "Audio.qml", w: 640, h: 320 },
  display:       { file: "Display.qml", w: 540, h: 300 },
  battery:       { file: "Battery.qml", w: 520, h: 240 },
  calendar:      { file: "Calendar.qml", w: 600, h: 340 },
  worldclock:    { file: "WorldClock.qml", w: 660, h: 350 },
  power:         { file: "Power.qml", w: 680, h: 156 },
  notifications: { file: "Notifications.qml", w: 500, h: 380 },
  system:        { file: "System.qml", w: 660, h: 440 },
  tray:          { file: "Tray.qml", w: 260, h: 72 },
  theme:         { file: "ThemePicker.qml", w: 720, h: 240 },
  look:          { file: "Look.qml", w: 640, h: 420 },
  weather:       { file: "Weather.qml", w: 460, h: 240 },
  agent:         { file: "Agent.qml", w: 620, h: 360 },
  menu:          { file: "Menu.qml", w: 580, h: 460 }
}
var fallback = { file: "Placeholder.qml", w: 420, h: 200 }

function entry(name) { return widgets[name] || fallback }
function fileOf(name) { return entry(name).file }
function width(name) { return entry(name).w }
function height(name) { return entry(name).h }
