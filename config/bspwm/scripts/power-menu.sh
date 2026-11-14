#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — power menu (Super+Shift+e / polybar power button)
command -v rofi >/dev/null 2>&1 || exit 1
choice=$(printf '󰌾  Bloquear\n󰍃  Cerrar sesión\n󰤄  Suspender\n󰜉  Reiniciar\n󰐥  Apagar' |
  rofi -dmenu -p "󰐥 Sesión" -i -no-custom -theme-str 'window {width: 300px;} listview {lines: 5;}') || exit 0
case "$choice" in
  *Bloquear*)  "$HOME/.config/bspwm/scripts/lock.sh" ;;
  *sesión*)    bspc quit ;;
  *Suspender*) systemctl suspend ;;
  *Reiniciar*) systemctl reboot ;;
  *Apagar*)    systemctl poweroff ;;
esac
