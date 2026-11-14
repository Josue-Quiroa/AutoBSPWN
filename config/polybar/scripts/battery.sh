#!/usr/bin/env bash
# Silent if no battery (VMs / desktops)
# shellcheck source=/dev/null
. "$(dirname "$0")/libcolors.sh"
bat=
for b in /sys/class/power_supply/BAT*; do
  [ -d "$b" ] || continue
  bat=$b
  break
done
[ -z "$bat" ] && exit 0
cap=$(cat "$bat/capacity" 2>/dev/null || true)
stat=$(cat "$bat/status" 2>/dev/null || true)
[[ "$cap" =~ ^[0-9]+$ ]] || exit 0
icon=󰁹
case "$stat" in
  Charging) icon=󰂄 ;;
  Full|"Not charging") icon=󰁹 ;;
  *)
    if [ "$cap" -lt 15 ]; then icon=󰂎
    elif [ "$cap" -lt 40 ]; then icon=󰁼
    elif [ "$cap" -lt 70 ]; then icon=󰁾
    else icon=󰂀; fi
    ;;
esac
ok=$(polycolor success '#a6e3a1')
bad=$(polycolor alert '#f38ba8')
fg=$ok
[ "$cap" -lt 20 ] && [ "$stat" != Charging ] && fg=$bad
echo "%{F$fg}$icon%{F-} $cap%"
