#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — Target HUD for polybar (reads what setFocus writes).
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
  echo "%{F$muted}󰓾 sin target%{F-}"
  exit 0
fi
# No name from setFocus? use /etc/hosts (no DNS: a reverse lookup over VPN can hang the bar)
if [ -z "$NAME" ] && [ -r /etc/hosts ]; then
  NAME=$(awk -v ip="$IP" '$1==ip{print $2; exit}' /etc/hosts 2>/dev/null)
fi
PORTS=
if [ -s "$T/$IP/ports.txt" ]; then
  PORTS=$(head -c 200 "$T/$IP/ports.txt" | tr -d '[:space:]')
  [ ${#PORTS} -gt 22 ] && PORTS="${PORTS:0:21}…"
fi
out="%{F$alert}󰓾%{F-}"
[ -n "$NAME" ] && out="$out %{F$fg}$NAME%{F-}"
out="$out %{F$muted}$IP%{F-}"
[ -n "$PORTS" ] && out="$out %{F$muted}[$PORTS]%{F-}"
echo "$out"
