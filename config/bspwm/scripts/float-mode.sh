#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — desktop float mode: arrange windows freely, like a normal desktop.
#   float-mode.sh             toggle the focused desktop  (Super+Shift+s)
#   float-mode.sh on|off      force it                    float-mode.sh --status (polybar)
#   float-mode.sh --watch     polybar tail module          float-mode.sh --prune (bspwmrc)
# ON : every window on that desktop floats (keeps its place/size) and new ones open floating;
#      Super + left-drag moves, Super + right-drag resizes. Super+s still flips one window.
# OFF: the windows this mode floated go back to automatic tiling.
# bspwmrc registers this script as bspwm's external_rules_command, so it is also called as
#   float-mode.sh <wid> <class> <instance> <consequences>   for every new window
#   (bspwm passes the window id in decimal; consequences = "monitor=… desktop=… state=…").
STATE="$HOME/.config/bspwm/.float-mode"            # desktop ids in float mode
NODES="$HOME/.config/bspwm/.float-mode.nodes"      # "<node> <desktop>" floated by this mode
ICON_FLOAT="󰖲"
ICON_TILED="󰕴"

in_state() { [ -f "$STATE" ] && grep -qxF "$1" "$STATE"; }

# ---- external rule (must be fast and never fail) ----------------------------
if [ $# -ge 4 ] && [[ "$1" =~ ^(0x[0-9a-fA-F]+|[0-9]+)$ ]]; then
  [ -s "$STATE" ] || exit 0
  wid=$(printf '0x%08X' "$1" 2>/dev/null) || wid=$1
  cons=$4
  # A rule already decided the state / unmanaged windows → leave them alone
  [[ " $cons " =~ \ state=[a-z_]+\  ]] && exit 0
  [[ " $cons " == *" manage=off "* ]] && exit 0
  desk=$(printf '%s\n' " $cons " | sed -n 's/.* desktop=\([^ ]*\) .*/\1/p')
  if [ -n "$desk" ]; then
    did=$(bspc query -D -d "$desk" 2>/dev/null | head -n1)
  else
    did=$(bspc query -D -d focused 2>/dev/null | head -n1)
  fi
  [ -n "$did" ] && in_state "$did" || exit 0
  printf '%s %s\n' "$wid" "$did" >>"$NODES" 2>/dev/null
  echo "state=floating"
  exit 0
fi

notify() { notify-send -a AutoBSPWN -u low -h string:x-dunst-stack-tag:floatmode "$1" "$2" 2>/dev/null || true; }

status() {
  local d
  d=$(bspc query -D -d focused 2>/dev/null) || { echo ""; return; }
  # AB_BAR_COMPACT=1 (narrow monitor, set by polybar/launch.sh): icon only
  if [ "${AB_BAR_COMPACT:-0}" = 1 ]; then
    if in_state "$d"; then echo "$ICON_FLOAT"; else echo "$ICON_TILED"; fi
  elif in_state "$d"; then echo "$ICON_FLOAT float"; else echo "$ICON_TILED tile"; fi
}

# Float one window at the place/size it had in the tiling ("x y w h" read BEFORE any
# window of the desktop was floated: floating one re-tiles the others)
float_in_place() {
  local n=$1 rect=$2 x y w h fx fy fw fh
  bspc node "$n" -t floating 2>/dev/null || return 1
  [ -n "$rect" ] && command -v jq >/dev/null 2>&1 || return 0
  read -r x y w h <<<"$rect"
  rect=$(bspc query -T -n "$n" 2>/dev/null | jq -r '.client.floatingRectangle | "\(.x) \(.y) \(.width) \(.height)"' 2>/dev/null) || return 0
  read -r fx fy fw fh <<<"$rect"
  [[ "$x$y$w$h$fx$fy$fw$fh" =~ ^[0-9-]+$ ]] || return 0
  bspc node "$n" -v $((x - fx)) $((y - fy)) 2>/dev/null || true
  bspc node "$n" -z bottom_right $((w - fw)) $((h - fh)) 2>/dev/null || true
}

turn_on() {
  local d=$1 n i
  local -a nodes=() rects=()
  in_state "$d" || printf '%s\n' "$d" >>"$STATE"
  for n in $(bspc query -N -d "$d" -n '.window.tiled.!hidden' 2>/dev/null); do
    nodes+=("$n")
    if command -v jq >/dev/null 2>&1; then
      rects+=("$(bspc query -T -n "$n" 2>/dev/null | jq -r '.client.tiledRectangle | "\(.x) \(.y) \(.width) \(.height)"' 2>/dev/null)")
    else
      rects+=("")
    fi
  done
  for i in "${!nodes[@]}"; do
    float_in_place "${nodes[$i]}" "${rects[$i]}" && printf '%s %s\n' "${nodes[$i]}" "$d" >>"$NODES"
  done
  notify "$ICON_FLOAT Modo flotante" "Escritorio $(bspc query -D -d "$d" --names 2>/dev/null): mueve con Super+clic izq. y redimensiona con Super+clic der. Super+Shift+s vuelve a mosaico."
}

turn_off() {
  local d=$1 n nd tmp
  if [ -f "$STATE" ]; then
    tmp=$(mktemp "$STATE.XXXXXX") || return 1
    grep -vxF "$d" "$STATE" >"$tmp" || true
    mv -f "$tmp" "$STATE"
  fi
  if [ -f "$NODES" ]; then
    tmp=$(mktemp "$NODES.XXXXXX") || return 1
    while read -r n nd; do
      [ -n "${n:-}" ] || continue
      # the window may have moved to another desktop meanwhile: use where it is now
      if bspc query -N -n "$n.floating" -d "$d" >/dev/null 2>&1; then
        bspc node "$n" -t tiled 2>/dev/null || true
      elif [ "$nd" != "$d" ]; then
        printf '%s %s\n' "$n" "$nd" >>"$tmp"
      fi
    done <"$NODES"
    mv -f "$tmp" "$NODES"
  fi
  notify "$ICON_TILED Modo mosaico" "Escritorio $(bspc query -D -d "$d" --names 2>/dev/null): las ventanas se acomodan solas otra vez."
}

prune() {
  local live tmp
  live=$(bspc query -D 2>/dev/null) || return 0
  if [ -f "$STATE" ]; then
    tmp=$(mktemp "$STATE.XXXXXX") || return 0
    grep -xF -f <(printf '%s\n' "$live") "$STATE" >"$tmp" || true
    mv -f "$tmp" "$STATE"
  fi
  if [ -f "$NODES" ]; then
    tmp=$(mktemp "$NODES.XXXXXX") || return 0
    while read -r n nd; do
      [ -n "${n:-}" ] && bspc query -N -n "$n" >/dev/null 2>&1 && printf '%s %s\n' "$n" "$nd"
    done <"$NODES" >"$tmp"
    mv -f "$tmp" "$NODES"
  fi
}

watch_mode() {
  local last="" cur rc
  cur=$(status); echo "$cur"; last=$cur
  # Instant update on desktop switch; the 2 s timeout catches toggles
  bspc subscribe desktop_focus 2>/dev/null | while true; do
    read -r -t 2 _
    rc=$?
    [ "$rc" -ne 0 ] && [ "$rc" -le 128 ] && break
    cur=$(status)
    [ "$cur" != "$last" ] && { echo "$cur"; last=$cur; }
  done
}

command -v bspc >/dev/null 2>&1 || { echo "bspc no encontrado" >&2; exit 1; }
mkdir -p "$(dirname "$STATE")"
case "${1:-toggle}" in
  toggle|"")
    d=$(bspc query -D -d focused) || exit 1
    if in_state "$d"; then turn_off "$d"; else turn_on "$d"; fi ;;
  on)       d=$(bspc query -D -d focused) || exit 1; in_state "$d" || turn_on "$d" ;;
  off)      d=$(bspc query -D -d focused) || exit 1; in_state "$d" && turn_off "$d" ;;
  --status) status ;;
  --watch)  watch_mode ;;
  --prune)  prune ;;
  -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "Uso: float-mode.sh [toggle|on|off|--status|--watch|--prune]" >&2; exit 1 ;;
esac
exit 0
