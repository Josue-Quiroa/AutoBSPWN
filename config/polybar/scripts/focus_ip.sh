#!/usr/bin/env bash
# AutoBSPWN v3.4.0 — Target HUD for polybar (reads what setFocus writes).
# v3.3: the whole section turns red when the target is OUT of its scope.conf (scope-check).
#   (no args)  print the HUD label
#   --copy     copy focus IP      --clear   run clearFocus
# Interactive actions live in ~/.config/bspwm/scripts/target-menu.sh
# shellcheck source=/dev/null
. "$(dirname "$0")/libcolors.sh"
F=$HOME/.config/bspwm/focus_ip
N=$HOME/.config/bspwm/focus_name
T=${AUTOBSPWN_TARGETS:-$HOME/targets}
IP=
NAME=
[ -f "$F" ] && IP=$(tr -d '[:space:]' <"$F")
[ -f "$N" ] && NAME=$(head -n1 "$N" | tr -d '\r\n')

case "${1:-}" in
  --clear)
    if [ -x "$HOME/.local/bin/clearFocus" ]; then
      exec "$HOME/.local/bin/clearFocus" >/dev/null
    fi
    rm -f "$F" "$N"
    exit 0
    ;;
  --copy)
    [ -n "$IP" ] || exit 0
    present_mode && exit 0
    { printf '%s' "$IP" | xclip -selection clipboard 2>/dev/null \
      || printf '%s' "$IP" | xsel -ib 2>/dev/null; } \
      && notify-send -a AutoBSPWN AutoBSPWN "Copiado: $IP" 2>/dev/null
    exit 0
    ;;
esac

muted=$(polycolor muted '#6c7086')
alert=$(polycolor alert '#f38ba8')
fg=$(polycolor foreground '#cdd6f4')
if [ -z "$IP" ]; then
  if [ "${AB_BAR_COMPACT:-0}" = 1 ]; then echo "%{F$muted}󰓾%{F-}"; else echo "%{F$muted}󰓾 sin target%{F-}"; fi
  exit 0
fi
# Presentation mode (Super+F12): never show the target on screen
if present_mode; then
  echo "%{F$muted}󰓾 target oculto%{F-}"
  exit 0
fi
# No name from setFocus? use /etc/hosts (no DNS: a reverse lookup over VPN can hang the bar)
if [ -z "$NAME" ] && [ -r /etc/hosts ]; then
  NAME=$(awk -v ip="$IP" '$1==ip{print $2; exit}' /etc/hosts 2>/dev/null)
fi
[ ${#NAME} -gt 18 ] && NAME="${NAME:0:17}…"
# Never let the name / IP files add polybar tags (%{A1:cmd:} would run cmd on click)
NAME=${NAME//%/}                       # no '%' at all: '%%{' would still open a tag
[[ $IP =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || IP="(IP inválida)"
# Narrow monitor (AB_BAR_COMPACT=1 from launch.sh): IP only
[ "${AB_BAR_COMPACT:-0}" = 1 ] && NAME=
# Open ports in the bar only on request (AUTOBSPWN_BAR_PORTS=1): they are in the target menu
PORTS=
if [ "${AUTOBSPWN_BAR_PORTS:-0}" = 1 ] && [ -s "$T/$IP/ports.txt" ]; then
  PORTS=$(head -c 200 "$T/$IP/ports.txt" | tr -d '[:space:]')
  [ ${#PORTS} -gt 22 ] && PORTS="${PORTS:0:21}…"
fi
# Scope guard (pure bash, offline): out of scope → everything in the alert color
scope_out=0
L=${AB_LIB:-$HOME/.config/bspwm/scripts/lib.sh}
if [ -r "$L" ]; then
  # shellcheck source=/dev/null
  if . "$L" 2>/dev/null && declare -F ab_scope_check >/dev/null; then
    rc=0
    ab_scope_check "$IP" >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 1 ] && scope_out=1
  fi
fi
if [ "$scope_out" = 1 ]; then
  out="%{F$alert}󰀦${NAME:+ $NAME} $IP"
  [ "${AB_BAR_COMPACT:-0}" = 1 ] || out="$out · fuera de scope"
  echo "$out%{F-}"
  exit 0
fi
out="%{F$alert}󰓾%{F-}"
[ -n "$NAME" ] && out="$out %{F$fg}$NAME%{F-}"
out="$out %{F$muted}$IP%{F-}"
[ -n "$PORTS" ] && out="$out %{F$muted}[$PORTS]%{F-}"
echo "$out"
