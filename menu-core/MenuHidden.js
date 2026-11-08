// The island's own rules for Omarchy's menu (the stock menu definition is never edited).
//
// hide:     id prefixes removed from the menu after the user jsonc merge, so search, recents and the rail drop them
//           too. A prefix is added in the SAME commit that adds the island widget which replaces it (see README).
//           Empty until the first widget addition lands (milestone M6).
// redirect: route -> island widget, used only when the route is hidden: a binding that asks the menu for a hidden
//           section opens the widget instead. Routes that are still in the menu (root, background, capture, share)
//           have no entry.
var hide = ["system"]

var redirect = {
  "system": "power",
  "power-menu": "power",
  "toggle": "home",
  "hardware": "display",
  "reminder-set": "calendar",
  "theme": "theme"
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
  if (!redirect[r]) return ""
  return isHiddenId(r, prefixes) || isHiddenId("route." + r, prefixes) ? redirect[r] : ""
}

if (typeof module !== "undefined") {
  module.exports = { hide: hide, redirect: redirect, isHiddenId: isHiddenId, redirectFor: redirectFor }
}
