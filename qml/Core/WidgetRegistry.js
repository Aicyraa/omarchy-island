.pragma library

// name -> { file, w, h }.
// w/h are estimates used on the first frames before the widget reports its implicit size.
var widgets = {
  settings:      { file: "Settings.qml", w: 680, h: 520 },
  home:          { file: "Settings.qml", w: 680, h: 520 },
  media:         { file: "Media.qml", w: 440, h: 140 },
  capture:       { file: "Capture.qml", w: 540, h: 364 },
  wifi:          { file: "Wifi.qml", w: 560, h: 397 },
  bluetooth:     { file: "Bluetooth.qml", w: 560, h: 213 },
  audio:         { file: "Audio.qml", w: 680, h: 288 },
  display:       { file: "Display.qml", w: 560, h: 309 },
  battery:       { file: "Battery.qml", w: 540, h: 281 },
  calendar:      { file: "Calendar.qml", w: 660, h: 304 },
  worldclock:    { file: "WorldClock.qml", w: 660, h: 291 },
  power:         { file: "Power.qml", w: 787, h: 128 },
  notifications: { file: "Notifications.qml", w: 540, h: 343 },
  system:        { file: "System.qml", w: 720, h: 194 },
  tray:          { file: "Tray.qml", w: 320, h: 111 },
  theme:         { file: "ThemePicker.qml", w: 720, h: 321 },
  look:          { file: "Look.qml", w: 660, h: 290 },
  weather:       { file: "Weather.qml", w: 540, h: 197 },
  agent:         { file: "Agent.qml", w: 640, h: 368 },
  menu:          { file: "Menu.qml", w: 660, h: 441 }
}
var fallback = { file: "Placeholder.qml", w: 420, h: 200 }

function entry(name) { return widgets[name] || fallback }
function fileOf(name) { return entry(name).file }
function width(name) { return entry(name).w }
function height(name) { return entry(name).h }
