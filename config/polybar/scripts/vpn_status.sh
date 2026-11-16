#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — VPN status for polybar
#   (no args)  label: icon + profile/connection name + tun IP (+N if several)
#   --ifaces   "iface<TAB>ipv4" for every VPN interface that is UP (used by vpn-menu.sh)
#   --copy     copy the first VPN IP      --menu   open vpn-menu.sh
# Detects OpenVPN tun/tap (any number: tun0, tun1…), WireGuard (wg-quick or nmcli,
# any interface name), ppp and NetworkManager VPN connections.
# shellcheck source=/dev/null
. "$(dirname "$0")/libcolors.sh"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/autobspwn"

case "${1:-}" in
  --menu)
    exec "$HOME/.config/bspwm/scripts/vpn-menu.sh"
    ;;
esac

vpn_ifaces() {
  local wg d i flags addr prio
  wg=" $(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 | tr '\n' ' ') "
  for d in /sys/class/net/*; do
    i=${d##*/}
    [ "$i" = lo ] && continue
    prio=
    if [ -e "$d/tun_flags" ]; then
      prio=1                                   # OpenVPN / tun / tap
      case "$i" in tailscale*|zt*) prio=3 ;;   # overlay meshes go last
      esac
    elif [[ "$wg" == *" $i "* ]]; then
      prio=1
    else
      case "$i" in
        tun*|tap*|wg*|ppp*|nordlynx|proton*) prio=2 ;;
      esac
    fi
    [ -n "$prio" ] || continue
    flags=$(cat "$d/flags" 2>/dev/null || echo 0)
    (( flags & 1 )) || continue                # IFF_UP
    addr=$(ip -4 -o addr show dev "$i" 2>/dev/null | awk '{print $4; exit}' | cut -d/ -f1)
    [ -n "$addr" ] || continue
    printf '%s\t%s\t%s\n' "$prio" "$i" "$addr"
  done | sort -t$'\t' -k1,1n -k2,2V | cut -f2-
}

mapfile -t IFS_UP < <(command -v ip >/dev/null 2>&1 && vpn_ifaces)

if [ "${1:-}" = --ifaces ]; then
  [ ${#IFS_UP[@]} -gt 0 ] && printf '%s\n' "${IFS_UP[@]}"
  exit 0
fi

IFACE=; IP=
if [ ${#IFS_UP[@]} -gt 0 ]; then
  IFACE=${IFS_UP[0]%%$'\t'*}
  IP=${IFS_UP[0]#*$'\t'}
fi

if [ "${1:-}" = --copy ]; then
  [ -n "$IP" ] || exit 0
  { printf '%s' "$IP" | xclip -selection clipboard 2>/dev/null || printf '%s' "$IP" | xsel -ib 2>/dev/null; } \
    && notify-send -a AutoBSPWN AutoBSPWN "VPN: $IP ($IFACE)" 2>/dev/null
  exit 0
fi

NM=
if command -v nmcli >/dev/null 2>&1; then
  NM=$(nmcli -t -f NAME,TYPE c show --active 2>/dev/null | awk -F: '$2=="vpn" || $2=="wireguard"{print $1; exit}')
fi
# Profile started from vpn-menu.sh (openvpn / wg-quick files in ~/vpn)
LABEL=$NM
if [ -z "$LABEL" ] && [ -n "$IFACE" ] && [ -s "$CACHE/vpn_active" ]; then
  IFS=$'\t' read -r vtype vid <"$CACHE/vpn_active"
  vname=${vid##*/}; vname=${vname%.*}
  case "$vtype" in
    wgfile) [ -e "/sys/class/net/$vname" ] && LABEL=$vname ;;
    ovpn)   pgrep -a -x openvpn 2>/dev/null | grep -qF -- "$vid" && LABEL=$vname ;;
  esac
fi

muted=$(polycolor muted '#6c7086')
ok=$(polycolor success '#a6e3a1')
warn=$(polycolor warning '#fab387')
if [ -z "$IFACE" ]; then
  if [ -n "$NM" ]; then
    echo "%{F$warn}󰒃%{F-} $NM…"        # NM says active but no tun IP yet
  else
    if [ "${AB_BAR_COMPACT:-0}" = 1 ]; then echo "%{F$muted}󰦞%{F-}"; else echo "%{F$muted}󰦞 VPN off%{F-}"; fi
  fi
  exit 0
fi
# Keep the bar compact: long profile names are shortened
[ ${#LABEL} -gt 18 ] && LABEL="${LABEL:0:17}…"
[ "${AB_BAR_COMPACT:-0}" = 1 ] && LABEL=
extra=
[ ${#IFS_UP[@]} -gt 1 ] && extra=" %{F$muted}+$(( ${#IFS_UP[@]} - 1 ))%{F-}"
if [ "${AB_BAR_COMPACT:-0}" = 1 ]; then
  echo "%{F$ok}󰕥 $IP%{F-}$extra"
else
  echo "%{F$ok}󰕥%{F-} ${LABEL:+$LABEL }%{F$ok}$IP%{F-}%{F$muted} $IFACE%{F-}$extra"
fi
