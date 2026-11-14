#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — smart resize (Super+Alt+arrows): grow towards the direction, and if the
# window is already at that edge, shrink from the opposite side. Works tiled and floating.
# (same idea as the classic bspwm_resize helper used by r1vs3c / yoodreamer; own code)
step=${AUTOBSPWN_RESIZE_STEP:-30}
case "${1:-}" in
  west)  bspc node -z left  -"$step" 0 2>/dev/null || bspc node -z right -"$step" 0 ;;
  east)  bspc node -z right  "$step" 0 2>/dev/null || bspc node -z left   "$step" 0 ;;
  north) bspc node -z top    0 -"$step" 2>/dev/null || bspc node -z bottom 0 -"$step" ;;
  south) bspc node -z bottom 0  "$step" 2>/dev/null || bspc node -z top    0  "$step" ;;
  *) echo "uso: $0 west|east|north|south" >&2; exit 1 ;;
esac
