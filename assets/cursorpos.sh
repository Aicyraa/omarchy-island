#!/bin/bash
# Prints "<cursor x on monitor> <cursor y on monitor> <monitor logical width>" for the monitor named $1.
read -r x y < <(hyprctl cursorpos | tr -d ,)
hyprctl monitors -j | jq -r --arg n "$1" --argjson x "${x:-0}" --argjson y "${y:-0}" '.[] | select(.name == $n) | "\($x - .x) \($y - .y) \(.width / .scale)"'
