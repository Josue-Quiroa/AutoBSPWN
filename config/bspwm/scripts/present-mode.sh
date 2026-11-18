#!/usr/bin/env bash
# AutoBSPWN v3.4.0 — presentation / recording mode (Super+F12)
#   present-mode.sh [--toggle]   switch it on/off        present-mode.sh --on | --off
#   present-mode.sh --status     prints on|off (exit 0 = on, 1 = off)
#   present-mode.sh --bar        polybar indicator (empty when off)
#   present-mode.sh --restore    re-apply the saved state (bspwmrc, at login)
# On: the bar hides the target IP/name, the VPN/tun IP and the LAN IP, and dunst notifications
# are paused (dunstctl set-paused true; they are shown when you turn it off).
# Saved in ~/.config/autobspwn/state (present=1), so it survives reloads and reboots.
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "$0")")/lib.sh"

dunst_pause() {   # dunst_pause true|false
  ab_has dunstctl || return 0
  dunstctl set-paused "$1" >/dev/null 2>&1 || true
}

turn_on() {
  ab_state_set present 1
  ab_notify "Modo presentación ON: IPs ocultas y notificaciones en pausa (Super+F12 para salir)" "Presentación"
  sleep 0.3
  dunst_pause true
}

turn_off() {
  ab_state_set present 0
  dunst_pause false
  ab_notify "Modo presentación OFF" "Presentación"
}

case "${1:---toggle}" in
  --toggle|toggle) if ab_present; then turn_off; else turn_on; fi ;;
  --on|on)         turn_on ;;
  --off|off)       turn_off ;;
  --status|status) if ab_present; then echo on; exit 0; else echo off; exit 1; fi ;;
  --bar)
    if ab_present; then
      alert='#f38ba8'
      C="$HOME/.config/polybar/scripts/libcolors.sh"
      # shellcheck source=/dev/null
      if [ -r "$C" ] && . "$C" 2>/dev/null; then alert=$(polycolor alert "$alert"); fi
      echo "%{F$alert}󰻃 REC%{F-}"
    else
      echo ""
    fi ;;
  --restore)
    if ab_present; then dunst_pause true; else dunst_pause false; fi ;;
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "uso: present-mode.sh [--toggle|--on|--off|--status|--bar|--restore]" >&2; exit 2 ;;
esac
exit 0
