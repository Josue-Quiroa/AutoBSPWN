#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — Super+Shift+arrows: move a floating window, swap a tiled one
step=${AUTOBSPWN_MOVE_STEP:-40}
dir=${1:-}
if bspc query -N -n focused.floating >/dev/null 2>&1; then
  case "$dir" in
    west)  bspc node -v -"$step" 0 ;;
    east)  bspc node -v  "$step" 0 ;;
    north) bspc node -v 0 -"$step" ;;
    south) bspc node -v 0  "$step" ;;
  esac
else
  bspc node -s "$dir" 2>/dev/null || bspc node -m "$dir" --follow 2>/dev/null || true
fi
