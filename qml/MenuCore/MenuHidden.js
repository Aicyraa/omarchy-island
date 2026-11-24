// The island's own rules for Omarchy's menu (the stock menu definition is never edited).
//
// hide:     id prefixes removed from the menu after the user jsonc merge, so search, recents and the rail drop them
//           too. A prefix is added in the SAME commit that adds the island widget which replaces it (see README).
//           Empty until the first widget addition lands (milestone M6).
// redirect: route -> island widget, used only when the route is hidden: a binding that asks the menu for a hidden
//           section opens the widget instead. Routes that are still in the menu (root, background, capture, share)
//           have no entry.
var hide = ["system", "trigger.toggle", "trigger.reminder", "setup.network.qr", "update.hardware.wifi", "update.hardware.bluetooth", "update.hardware.audio", "trigger.hardware.laptop-display-on", "trigger.hardware.laptop-display-off", "trigger.hardware.mirror-display-on", "trigger.hardware.mirror-display-off", "trigger.hardware.touchpad-on", "trigger.hardware.touchpad-off", "trigger.hardware.touchscreen-on", "trigger.hardware.touchscreen-off", "appearance.theme", "appearance.background", "appearance.font", "appearance.top-bar", "appearance.animations-on", "appearance.animations-off"]

var redirect = {
  "system": "power",
  "power-menu": "power",
  "toggle": "settings",
  "top-bar": "settings",
  "bar": "settings",
  "appearance.top-bar": "settings",
  "hardware": "display",
  "reminder-set": "calendar",
  "reminder": "calendar",
  "wifi-qr": "wifi",
  "theme": "theme",
  "themes": "theme",
  "background": "look",
  "wallpaper": "look",
  "font": "look",
  "appearance.theme": "theme",
  "appearance.background": "look",
  "appearance.font": "look"
}

// The stock menu id each redirect route stands for. The redirect applies when that section is hidden (an alias such as
// "toggle" is not in the tree once its section is hidden, so the route name alone cannot say whether it is hidden).
// A widget entered with an intent (see State.intent). The QR entry asks the Wi-Fi widget to show its code.
var intents = {
  "wifi-qr": "wifi-share",
  "background": "background",
  "wallpaper": "background",
  "font": "font",
  "appearance.background": "background",
  "appearance.font": "font"
}

var sourceId = {
  "system": "system",
  "power-menu": "system",
  "toggle": "trigger.toggle",
  "top-bar": "appearance.top-bar",
  "bar": "appearance.top-bar",
  "appearance.top-bar": "appearance.top-bar",
  "hardware": "trigger.hardware",
  "reminder-set": "trigger.reminder",
  "reminder": "trigger.reminder",
  "wifi-qr": "setup.network.qr",
  "theme": "appearance.theme",
  "themes": "appearance.theme",
  "background": "appearance.background",
  "wallpaper": "appearance.background",
  "font": "appearance.font",
  "appearance.theme": "appearance.theme",
  "appearance.background": "appearance.background",
  "appearance.font": "appearance.font"
}

function isHiddenId(id, prefixes) {
  var list = prefixes || hide
  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    if (id === p || String(id).indexOf(p + ".") === 0) return true
  }
  return false
}

// The widget a route should open instead, or "" when the route stays in the menu.
function redirectFor(route, prefixes) {
  var r = String(route || "")
  if (!redirect[r] || !sourceId[r]) return ""
  return isHiddenId(sourceId[r], prefixes) ? redirect[r] : ""
}

if (typeof module !== "undefined") {
  module.exports = { hide: hide, redirect: redirect, intents: intents, sourceId: sourceId, isHiddenId: isHiddenId, redirectFor: redirectFor }
}
