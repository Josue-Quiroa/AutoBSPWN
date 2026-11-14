#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — screenshots saved to ~/Pictures/Screenshots AND copied to the clipboard
# (yoodreamer/AutoBSPWM idea: capture + clipboard; own code)
#   screenshot.sh area     select a region (flameshot GUI)     Super+a / Print
#   screenshot.sh full     whole screen                        Super+Print
#   screenshot.sh window   focused window                      Super+Shift+Print
#   screenshot.sh delay    whole screen after 5 s              Super+Ctrl+Print
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
DIR="${AUTOBSPWN_SHOTS:-$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots}"
mkdir -p "$DIR"
out="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"
mode=${1:-area}

to_clip() {
  [ -s "$1" ] || return 1
  ab_has xclip && xclip -selection clipboard -t image/png -i "$1" 2>/dev/null
  ab_notify "Captura guardada y copiada: ${1/#$HOME/\~}" "Captura"
}

if [ "$mode" = area ] && ab_has flameshot; then
  # flameshot copies to the clipboard itself (-c) and saves to -p
  flameshot gui -c -p "$DIR" >/dev/null 2>&1 &
  exit 0
fi

wid=
[ "$mode" = window ] && wid=$(xdotool getactivewindow 2>/dev/null)
[ "$mode" = delay ] && { ab_notify "Captura en 5 s…" "Captura"; sleep 5; }

if ab_has maim; then
  case "$mode" in
    area)   maim -s -u "$out" ;;
    window) maim -u ${wid:+-i "$wid"} "$out" ;;
    *)      maim -u "$out" ;;
  esac
elif ab_has scrot; then
  case "$mode" in
    area)   scrot -s -o "$out" ;;
    window) scrot -u -o "$out" ;;
    *)      scrot -o "$out" ;;
  esac
elif ab_has flameshot; then
  flameshot full -c -p "$DIR" >/dev/null 2>&1; exit 0
elif ab_has import; then
  case "$mode" in
    area)   import "$out" ;;
    window) import -window "${wid:-root}" "$out" ;;
    *)      import -window root "$out" ;;
  esac
else
  ab_notify "Instala flameshot, maim o scrot" "Captura"; exit 1
fi
to_clip "$out"
