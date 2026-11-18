#!/usr/bin/env bash
# AutoBSPWN v3.4.0
# Launch polybar on every monitor. Tray only on the first bar.
# Kali (polybar 3.7+) uses internal/tray; Parrot/Debian 12 (3.6) uses tray-position.

CFG="$HOME/.config/polybar/config.ini"
[ -f "$CFG" ] || exit 1
cd "$HOME/.config/polybar" || exit 1
export PATH="$HOME/.local/bin:$PATH"

# Default-route interface for the netspeed module (wired or wifi)
iface=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
if [ -z "$iface" ]; then
  iface=$(ip -br link 2>/dev/null | awk '$1!="lo" && $2=="UP"{print $1; exit}')
fi
export POLYBAR_NET_IFACE="${iface:-}"

polybar_major=0
polybar_minor=0
ver=$(polybar -v 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
if [ -n "$ver" ]; then
  polybar_major=${ver%%.*}
  polybar_minor=${ver#*.}
fi
# 3.7+ has internal/tray
if [ "$polybar_major" -gt 3 ] 2>/dev/null || { [ "$polybar_major" -eq 3 ] && [ "$polybar_minor" -ge 7 ]; }; then
  TRAY_MOD=tray
  TRAY_POS=none
else
  TRAY_MOD=
  TRAY_POS=right
fi

# Only this user's bars (pkill from procps; killall/psmisc is not always installed)
pkill -u "$(id -u)" -x polybar 2>/dev/null || true
for _ in $(seq 1 20); do
  pgrep -u "$(id -u)" -x polybar >/dev/null 2>&1 || break
  sleep 0.1
done
if pgrep -u "$(id -u)" -x polybar >/dev/null 2>&1; then
  pkill -9 -u "$(id -u)" -x polybar 2>/dev/null || true
  sleep 0.1
fi

# Narrow monitors (< 1366 px, e.g. 1024x768 / 1280x800 VMs) get compact labels
# (time only, icon-only VPN-off / float mode, target IP without the name) so the
# right side never runs off the bar. Force with AUTOBSPWN_BAR_COMPACT=0|1.
mon_width() {
  local w
  w=$(polybar -m 2>/dev/null | awk -F'[ :x]+' -v m="$1" '$1==m || m=="" {print $2; exit}')
  [[ $w =~ ^[0-9]+$ ]] || w=$(xrandr --current 2>/dev/null | sed -n 's/.*current \([0-9]*\) x.*/\1/p' | head -n1)
  printf '%s\n' "${w:-1920}"
}

# v3.4 HiDPI: per-monitor DPI from monitors.sh (xrandr physical size; state dpi=N forces it)
mon_dpi() {
  local d=96 m="$HOME/.config/bspwm/scripts/monitors.sh"
  [ -x "$m" ] && d=$("$m" --dpi "$1" 2>/dev/null)
  [[ $d =~ ^[0-9]+$ ]] && [ "$d" -ge 48 ] || d=96
  printf '%s\n' "$d"
}

launch_bar() {
  local mon=$1 tray_mod=$2 tray_pos=$3 bar=main compact=${AUTOBSPWN_BAR_COMPACT:-} dpi w
  [ "$tray_mod" = tray ] && bar=main-tray
  dpi=$(mon_dpi "$mon")
  if [ -z "$compact" ]; then
    compact=0
    # width in 96-dpi pixels: a 2560 px HiDPI laptop is as narrow as a 1280 px one
    w=$(mon_width "$mon")
    [ $(( w * 96 / dpi )) -lt 1366 ] 2>/dev/null && compact=1
  fi
  AB_BAR_COMPACT="$compact" MONITOR="$mon" POLYBAR_TRAY_POS="$tray_pos" \
    POLYBAR_DPI="$dpi" POLYBAR_HEIGHT="$(( (30 * dpi + 48) / 96 ))" polybar -q -r "$bar" -c "$CFG" &
}

first=1
if polybar -m >/dev/null 2>&1; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    m=${line%%:*}
    [ -n "$m" ] || continue
    if [ "$first" -eq 1 ]; then
      launch_bar "$m" "$TRAY_MOD" "$TRAY_POS"
      first=0
    else
      # No tray on secondary bars (system tray is unique)
      launch_bar "$m" "" none
    fi
  done < <(polybar -m)
fi
if [ "$first" -eq 1 ]; then
  launch_bar "${MONITOR:-}" "$TRAY_MOD" "$TRAY_POS"
fi
