#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — local IP for polybar (left click copies it)
# shellcheck source=/dev/null
. "$(dirname "$0")/libcolors.sh"
copy(){ printf '%s' "$1" | xclip -selection clipboard 2>/dev/null || printf '%s' "$1" | xsel -ib 2>/dev/null || true; }
IP=
if command -v ip >/dev/null 2>&1; then
  IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}')
fi
[ -z "$IP" ] && IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$IP" ] && IP=offline
if [ "${1:-}" = --copy ]; then
  copy "$IP"
  command -v notify-send >/dev/null 2>&1 && notify-send AutoBSPWN "ETH: $IP"
  exit 0
fi
muted=$(polycolor muted '#6c7086')
blue=$(polycolor secondary '#89b4fa')
if [ "$IP" = offline ]; then
  echo "%{F$muted}󰌙%{F-} offline"
else
  echo "%{F$blue}%{F-} $IP"
fi
