#!/usr/bin/env bash
# AutoBSPWN v3.4.2 — desktops with one or more monitors (all desktop keys go through here)
#   desktop.sh focus <n>         Super+1..0         go to desktop n
#   desktop.sh send <n>          Super+Shift+1..0   move the focused window there (and follow it)
#   desktop.sh other-focus <n>   Super+Alt+1..0     go to the n-th desktop OF THE OTHER MONITOR
#   desktop.sh other-send <n>    Super+Alt+Shift+1..0   send the window there (and follow it)
#   desktop.sh other             print the name of the "other" monitor (empty with one monitor)
# desktops=split (default, ~/.config/autobspwn/state): I–X are spread over the monitors → n is
# global (Super+7 is desktop VII wherever it lives; with 2 monitors 1–5 = main, 6–0 = second).
# desktops=each: I–X on every monitor → n is counted on the focused monitor.
# "The other monitor": second_monitor=<name> in the state file if that monitor exists; else the
# monitor after the primary one in bspwm's order (xrandr primary, or the first monitor), wrapping
# around. With 2 monitors that is always the secondary one; with 3+ it is the one after the main.
# With a single monitor the other-* actions behave like focus / send.
n=${2:-}
act=${1:-}
case "$act" in
  other) ;;
  focus|send|other-focus|other-send) [[ $n =~ ^([1-9]|10)$ ]] || exit 2 ;;
  *) exit 2 ;;
esac
f="${AUTOBSPWN_STATE:-$HOME/.config/autobspwn/state}"
sget() { [ -r "$f" ] && awk -v k="$1" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2) } END { print v }' "$f"; }
mode='split'
[ "$(sget desktops)" = each ] && mode=each

other_monitor() {
  local -a mons=()
  local m want prim i
  mapfile -t mons < <(bspc query -M --names 2>/dev/null)
  (( ${#mons[@]} > 1 )) || return 1
  want=$(sget second_monitor)
  if [ -n "$want" ]; then
    for m in "${mons[@]}"; do [ "$m" = "$want" ] && { echo "$m"; return 0; }; done
  fi
  prim=$(bspc query -M -m primary --names 2>/dev/null | head -n1)
  [ -n "$prim" ] || prim=${mons[0]}
  for i in "${!mons[@]}"; do
    if [ "${mons[$i]}" = "$prim" ]; then echo "${mons[$(( (i + 1) % ${#mons[@]} ))]}"; return 0; fi
  done
  echo "${mons[1]}"
}

say() { command -v notify-send >/dev/null 2>&1 && notify-send -a AutoBSPWN -t 2500 "Escritorios" "$1"; return 0; }

if [ "$mode" = each ]; then sel="focused:^$n"; else sel="^$n"; fi
case "$act" in
  other) other_monitor || true; exit 0 ;;
  other-focus|other-send)
    if mon=$(other_monitor); then
      cnt=$(bspc query -D -m "$mon" 2>/dev/null | wc -l)
      if (( n > cnt )); then say "El monitor $mon tiene $cnt escritorios (pediste el $n)"; exit 1; fi
      sel="$mon:^$n"
    fi
    act=${act#other-} ;;
esac
case "$act" in
  focus) bspc desktop -f "$sel" ;;
  send)  bspc node -d "$sel" --follow ;;
esac
