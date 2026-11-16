#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — keyboard resize (Super+Alt+arrows / Super+Alt+hjkl).
#   Floating window : Left/Right = narrower/wider, Up/Down = shorter/taller
#                     (anchored on the top-left corner, so it never "only grows").
#   Tiled window    : smart resize — push the split towards the arrow; if the window
#                     is already at that edge, pull the opposite side instead.
#   Optional 2nd arg: grow|shrink to force the behaviour (Super+Alt+Shift = shrink).
# (same idea as the classic bspwm_resize helper used by r1vs3c / yoodreamer; own code)
step=${AUTOBSPWN_RESIZE_STEP:-30}
dir=${1:-}
mode=${2:-}

is_floating() { bspc query -N -n focused.floating >/dev/null 2>&1; }

if [[ -z $dir ]] || ! [[ $dir =~ ^(west|east|north|south)$ ]]; then
  echo "uso: $0 west|east|north|south [grow|shrink]" >&2; exit 1
fi
bspc query -N -n focused >/dev/null 2>&1 || exit 0

if is_floating; then
  # Floating: always resize from the right / bottom edge (predictable, both ways).
  case "$dir" in
    west)  dx=-$step; dy=0 ;;
    east)  dx=$step;  dy=0 ;;
    north) dx=0; dy=-$step ;;
    south) dx=0; dy=$step ;;
  esac
  if [[ $mode == shrink ]]; then dx=-${dx#-}; dy=-${dy#-}; fi
  if [[ $mode == grow ]];   then dx=${dx#-};  dy=${dy#-};  fi
  [[ $dx == -0 ]] && dx=0; [[ $dy == -0 ]] && dy=0
  if [[ $dx != 0 ]]; then bspc node -z right "$dx" 0 2>/dev/null || true; fi
  if [[ $dy != 0 ]]; then bspc node -z bottom 0 "$dy" 2>/dev/null || true; fi
  exit 0
fi

# Tiled (or pseudo-tiled): grow towards the direction, else shrink from the other side.
if [[ $mode == shrink ]]; then
  case "$dir" in
    west)  bspc node -z right -"$step" 0 2>/dev/null || bspc node -z left   "$step" 0 2>/dev/null ;;
    east)  bspc node -z left   "$step" 0 2>/dev/null || bspc node -z right -"$step" 0 2>/dev/null ;;
    north) bspc node -z bottom 0 -"$step" 2>/dev/null || bspc node -z top   0  "$step" 2>/dev/null ;;
    south) bspc node -z top    0  "$step" 2>/dev/null || bspc node -z bottom 0 -"$step" 2>/dev/null ;;
  esac
  exit 0
fi
case "$dir" in
  west)  bspc node -z left  -"$step" 0 2>/dev/null || bspc node -z right -"$step" 0 2>/dev/null ;;
  east)  bspc node -z right  "$step" 0 2>/dev/null || bspc node -z left   "$step" 0 2>/dev/null ;;
  north) bspc node -z top    0 -"$step" 2>/dev/null || bspc node -z bottom 0 -"$step" 2>/dev/null ;;
  south) bspc node -z bottom 0  "$step" 2>/dev/null || bspc node -z top    0  "$step" 2>/dev/null ;;
esac
exit 0
