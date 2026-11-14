#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — wallpaper picker with previews (Super+w)
#   wallpaper.sh            rofi grid with thumbnails of ~/.config/bspwm/walls/*
#   wallpaper.sh --random   random wallpaper (Super+Shift+w)
#   wallpaper.sh FILE       set FILE
# The choice is saved in ~/.fehbg (restored at login). Theme changes switch to the theme's
# wallpaper unless ~/.config/bspwm/.no-theme-wall exists.
# shellcheck source=/dev/null
. "$(dirname "$0")/lib.sh"
DIR="$HOME/.config/bspwm/walls"
THUMBS="$AB_CACHE/wall-thumbs"
mkdir -p "$DIR" "$THUMBS"

set_wall() {
  ab_has feh || { ab_notify "feh no está instalado"; return 1; }
  feh --bg-fill "$1" && ab_notify "Wallpaper: $(basename "$1")"
}

mapfile -t files < <(find -L "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort)
if [ ${#files[@]} -eq 0 ]; then
  ab_notify "Sin wallpapers en $DIR"
  exit 1
fi

case "${1:-}" in
  --random) set_wall "${files[RANDOM % ${#files[@]}]}"; exit $? ;;
  "") ;;
  *) [ -f "$1" ] && { set_wall "$1"; exit $?; }; ab_notify "No existe: $1"; exit 1 ;;
esac

ab_need_rofi
# Thumbnails (cached; regenerated when the wallpaper changes)
conv=
if ab_has magick; then conv=magick; elif ab_has convert; then conv=convert; fi
thumb() {
  local f=$1 t
  t="$THUMBS/$(basename "${f%.*}").jpg"
  if [ -n "$conv" ] && { [ ! -s "$t" ] || [ "$f" -nt "$t" ]; }; then
    "$conv" "${f}[0]" -thumbnail 480x270^ -gravity center -extent 480x270 -quality 82 "$t" 2>/dev/null || rm -f "$t"
  fi
  [ -s "$t" ] && printf '%s\n' "$t" || printf '%s\n' "$f"
}

current=$(sed -n "s/.*--bg-[a-z]* *'\(.*\)'.*/\1/p" "$HOME/.fehbg" 2>/dev/null | head -n1)
entries() {
  printf '󰒝  Aleatorio\0icon\x1fmedia-playlist-shuffle\n'
  local f n
  for f in "${files[@]}"; do
    n=$(basename "${f%.*}"); [ "$f" = "$current" ] && n="● $n"
    printf '%s\0icon\x1f%s\n' "$n" "$(thumb "$f")"
  done
}
pick=$(entries | rofi -dmenu -i -p "󰸉 Wallpaper" -show-icons -format i -no-custom \
  -mesg "Enter: aplicar · añade imágenes en ~/.config/bspwm/walls" \
  -theme-str 'window {width: 1000px;} listview {columns: 3; lines: 3; spacing: 10px;}
              element {orientation: vertical; padding: 8px; spacing: 6px;}
              element-icon {size: 160px; horizontal-align: 0.5;} element-text {horizontal-align: 0.5;}') || exit 0
[[ "$pick" =~ ^[0-9]+$ ]] || exit 0
if [ "$pick" -eq 0 ]; then
  set_wall "${files[RANDOM % ${#files[@]}]}"
else
  set_wall "${files[$((pick - 1))]}"
fi
