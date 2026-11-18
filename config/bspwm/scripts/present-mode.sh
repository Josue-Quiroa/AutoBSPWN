#!/usr/bin/env bash
# AutoBSPWN v3.4.2 — presentation mode (Super+F12)
#   present-mode.sh [--toggle]   switch it on/off        present-mode.sh --on | --off
#   present-mode.sh --status     prints on|off (exit 0 = on, 1 = off)
#   present-mode.sh --bar        polybar indicator (empty when off and not recording)
#   present-mode.sh --restore    re-apply the saved state (bspwmrc, at login)
# What it does: the bar hides the target IP/name, the VPN/tun IP and the LAN IP, and dunst
# notifications are paused (dunstctl set-paused true; you get them when you turn it off).
# It does NOT record the screen by itself: recording is record.sh (Super+Shift+F12, folder and
# options in Super+Alt+F12). With record_with_present=1 in the state file it also starts a
# recording on --on and stops it (and tells you the file) on --off.
# Saved in ~/.config/autobspwn/state (present=1), so it survives reloads and reboots.
# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "$0")")/lib.sh"

REC="$(dirname "$(readlink -f "$0")")/record.sh"

dunst_pause() {   # dunst_pause true|false
  ab_has dunstctl || return 0
  dunstctl set-paused "$1" >/dev/null 2>&1 || true
}

nice_path() { printf '%s\n' "${1/#"$HOME"/\~}"; }

turn_on() {
  local msg out file
  ab_state_set present 1
  msg="Modo presentación ON: la barra oculta la IP y el nombre del target, la VPN y la IP LAN, y las notificaciones quedan en pausa."
  if [ "$(ab_state_get record_with_present 0)" = 1 ]; then
    if out=$("$REC" --start present 2>&1); then
      file=$(sed -n 's/^\[+\] grabando .* → //p' <<<"$out")
      [ -n "$file" ] || file=$("$REC" --status 2>/dev/null | cut -d' ' -f2-)
      msg+=" Grabando la pantalla → $(nice_path "$file")."
    else
      msg+=" NO se pudo grabar: ${out##*\] }"
    fi
  else
    msg+=" NO graba la pantalla: Super+Shift+F12 graba en $(nice_path "$("$REC" --dir)") (carpeta y opciones: Super+Alt+F12)."
  fi
  echo "$msg"
  ab_notify "$msg Super+F12 para salir." "Presentación"
  sleep 0.3
  dunst_pause true
}

turn_off() {
  local msg="Modo presentación OFF." out file
  ab_state_set present 0
  if [ "$("$REC" --origin 2>/dev/null)" = present ]; then
    out=$("$REC" --stop quiet 2>&1)
    file=$(sed -n 's/^\[+\] grabación guardada: \(.*\) (.*)$/\1/p' <<<"$out")
    if [ -n "$file" ]; then msg+=" Grabación guardada en $(nice_path "$file")"
    else msg+=" ${out##*\] }"; fi
  fi
  dunst_pause false
  echo "$msg"
  ab_notify "$msg" "Presentación"
}

case "${1:---toggle}" in
  --toggle|toggle) if ab_present; then turn_off; else turn_on; fi ;;
  --on|on)         turn_on ;;
  --off|off)       turn_off ;;
  --status|status) if ab_present; then echo on; exit 0; else echo off; exit 1; fi ;;
  --bar)
    out=''
    if ab_present || [ -s "$AB_CACHE/record.pid" ]; then
      alert='#f38ba8'; warn='#f9e2af'
      C="$HOME/.config/polybar/scripts/libcolors.sh"
      # shellcheck source=/dev/null
      if [ -r "$C" ] && . "$C" 2>/dev/null; then alert=$(polycolor alert "$alert"); warn=$(polycolor warning "$warn"); fi
      ab_present && out="%{F$warn}󰈉 OCULTO%{F-}"
      "$REC" --status >/dev/null 2>&1 && out+="${out:+ }%{F$alert}󰻃 REC%{F-}"
    fi
    echo "$out" ;;
  --restore)
    if ab_present; then dunst_pause true; else dunst_pause false; fi ;;
  -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "uso: present-mode.sh [--toggle|--on|--off|--status|--bar|--restore]" >&2; exit 2 ;;
esac
exit 0
