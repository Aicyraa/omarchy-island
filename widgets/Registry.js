.pragma library

// name -> { file, w, h }. Sizes are the widget's panel size in px (the hint row
// is added on top by Island). Names not listed here fall back to Placeholder.
var widgets = {
  home:  { file: "Home.qml",  w: 480, h: 322 },
  wifi:      { file: "Wifi.qml",      w: 480, h: 380 },
  bluetooth: { file: "Bluetooth.qml", w: 460, h: 340 },
  audio:     { file: "Audio.qml",     w: 680, h: 340 },
  display:   { file: "Display.qml",   w: 460, h: 246 },
  battery:   { file: "Battery.qml",   w: 460, h: 236 },
  calendar:  { file: "Calendar.qml",  w: 400, h: 330 },
  worldclock:{ file: "WorldClock.qml",w: 620, h: 340 },
  system:    { file: "System.qml",    w: 620, h: 190 },
  power: { file: "Power.qml", w: 580, h: 236 }
}
var fallback = { file: "Placeholder.qml", w: 420, h: 200 }

function entry(name) { return widgets[name] || fallback }
function fileOf(name) { return entry(name).file }
function width(name) { return entry(name).w }
function height(name) { return entry(name).h }
