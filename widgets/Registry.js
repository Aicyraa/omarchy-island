.pragma library

// name -> { file, w, h }. Sizes are the widget's panel size in px (the hint row
// is added on top by Island). Names not listed here fall back to Placeholder.
var widgets = {
  power: { file: "Power.qml", w: 580, h: 236 }
}
var fallback = { file: "Placeholder.qml", w: 420, h: 200 }

function entry(name) { return widgets[name] || fallback }
function fileOf(name) { return entry(name).file }
function width(name) { return entry(name).w }
function height(name) { return entry(name).h }
