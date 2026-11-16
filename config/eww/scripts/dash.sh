#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — data + actions for the eww dashboard (~/.config/eww/eww.yuck)
S="$HOME/.config/bspwm/scripts"
P="$HOME/.config/polybar/scripts"
close() { "$S/dashboard.sh" --close >/dev/null 2>&1; }

# Actions close the dashboard, which kills the eww daemon (and its children):
# detach first so the action itself survives.
case "${1:-}" in
  run|lock|logout|suspend|reboot|poweroff)
    if [ -z "${AB_DASH_DETACHED:-}" ]; then
      AB_DASH_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
      exit 0
    fi ;;
esac

case "${1:-}" in
  user)   getent passwd "$(id -un)" | cut -d: -f5 | cut -d, -f1 | grep . || id -un ;;
  host)   hostname 2>/dev/null || cat /etc/hostname ;;
  kernel) uname -r ;;
  uptime) uptime -p 2>/dev/null | sed 's/^up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/; s/ weeks\?/w/g' ;;
  vpn)
    l=$("$P/vpn_status.sh" --ifaces 2>/dev/null | head -n1)
    if [ -n "$l" ]; then printf '%s\n%s\n' "${l#*$'\t'}" "${l%%$'\t'*}"; else printf 'VPN\ndesconectada\n'; fi ;;
  target)
    ip=$(tr -d '[:space:]' 2>/dev/null <"$HOME/.config/bspwm/focus_ip" || true)
    name=$(head -n1 "$HOME/.config/bspwm/focus_name" 2>/dev/null | tr -d '\r\n')
    [ ${#name} -gt 22 ] && name="${name:0:21}…"
    if [ -n "$ip" ]; then printf '%s\n%s\n' "$ip" "${name:-sin nombre}"; else printf 'Sin target\nSuper+i para fijarlo\n'; fi ;;
  volume)
    v=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -n1 | tr -d %)
    [ -n "$v" ] || v=$(amixer get Master 2>/dev/null | grep -oE '[0-9]+%' | head -n1 | tr -d %)
    echo "${v:-0}" ;;
  setvol)
    v=${2%.*}; [[ $v =~ ^[0-9]+$ ]] || exit 0; [ "$v" -gt 100 ] && v=100
    pactl set-sink-volume @DEFAULT_SINK@ "$v%" 2>/dev/null || amixer -q set Master "$v%" 2>/dev/null || true ;;
  bright)
    if command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m >/dev/null 2>&1 \
       && [ -n "$(ls /sys/class/backlight 2>/dev/null)" ]; then
      brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d % | head -n1
    elif command -v xbacklight >/dev/null 2>&1 && xbacklight -get >/dev/null 2>&1; then
      xbacklight -get | cut -d. -f1
    else
      echo "n/a"      # VMs / desktops without a backlight
    fi ;;
  setbright)
    v=${2%.*}; [[ $v =~ ^[0-9]+$ ]] || exit 0; [ "$v" -lt 1 ] && v=1; [ "$v" -gt 100 ] && v=100
    brightnessctl -q set "$v%" 2>/dev/null || xbacklight -set "$v" 2>/dev/null || true ;;
  run)
    close
    case "${2:-}" in
      terminal) setsid -f kitty >/dev/null 2>&1 ;;
      browser)  setsid -f "$S/browser.sh" >/dev/null 2>&1 ;;
      files)    setsid -f "$S/files.sh" >/dev/null 2>&1 ;;
      tools)    setsid -f "$S/tools-menu.sh" >/dev/null 2>&1 ;;
      target)   setsid -f "$S/target-menu.sh" >/dev/null 2>&1 ;;
      vpn)      setsid -f "$S/vpn-menu.sh" >/dev/null 2>&1 ;;
    esac ;;
  lock)     close; setsid -f "$S/lock.sh" >/dev/null 2>&1 ;;
  logout)   close; bspc quit ;;
  suspend)  close; "$S/lock.sh" & sleep 1; systemctl suspend ;;
  reboot)   close; systemctl reboot ;;
  poweroff) close; systemctl poweroff ;;
  *) echo "uso: $0 user|host|kernel|uptime|vpn|target|volume|setvol N|bright|setbright N|run APP|lock|logout|suspend|reboot|poweroff" >&2; exit 1 ;;
esac
