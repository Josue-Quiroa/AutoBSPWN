#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — "minimize" windows in bspwm (idea from yoodreamer/AutoBSPWM; own code)
#   hide-node.sh --hide      hide the focused window          (Super+n)
#   hide-node.sh --menu      rofi list of hidden windows → restore   (Super+Shift+n)
#   hide-node.sh --last      restore the most recently hidden one
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
STACK="$AB_CACHE/hidden-nodes"
touch "$STACK"

title() {
  local t
  t=$(xprop -id "$1" _NET_WM_NAME 2>/dev/null | sed -n 's/^[^"]*"\(.*\)"$/\1/p')
  [ -n "$t" ] || t=$(xprop -id "$1" WM_CLASS 2>/dev/null | sed -n 's/.*"\([^"]*\)"$/\1/p')
  printf '%s\n' "${t:-$1}"
}

restore() {
  local wid=$1
  bspc node "$wid" -g hidden=off 2>/dev/null || return 1
  bspc node "$wid" -d focused 2>/dev/null || true
  bspc node "$wid" -f 2>/dev/null || true
  grep -v -x -- "$wid" "$STACK" >"$STACK.tmp" 2>/dev/null; mv -f "$STACK.tmp" "$STACK"
}

# keep only windows that still exist and are hidden
live() { bspc query -N -n .hidden.window 2>/dev/null; }

case "${1:---hide}" in
  --hide)
    wid=$(bspc query -N -n focused.window 2>/dev/null) || exit 0
    bspc node "$wid" -g hidden=on && printf '%s\n' "$wid" >>"$STACK"
    ab_notify "Ventana oculta: $(title "$wid") · Super+Shift+n para recuperarla"
    ;;
  --last)
    mapfile -t ids < <(live)
    [ ${#ids[@]} -gt 0 ] || { ab_notify "No hay ventanas ocultas"; exit 0; }
    wid=$(tac "$STACK" | while read -r w; do printf '%s\n' "${ids[@]}" | grep -qx -- "$w" && { echo "$w"; break; }; done)
    restore "${wid:-${ids[0]}}"
    ;;
  --menu)
    ab_need_rofi
    mapfile -t ids < <(live)
    [ ${#ids[@]} -gt 0 ] || { ab_notify "No hay ventanas ocultas"; exit 0; }
    i=$(for w in "${ids[@]}"; do printf '󰘸  %s\n' "$(title "$w")"; done \
          | ab_menu "Ocultas" -format i -no-custom -mesg "Enter: restaurar en este escritorio") || exit 0
    [[ "$i" =~ ^[0-9]+$ ]] && restore "${ids[$i]}"
    ;;
esac
