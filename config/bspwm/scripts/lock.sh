#!/usr/bin/env bash
# AutoBSPWN v3.2.0 — lock screen (Super+Shift+x / Ctrl+Alt+l / power menu)
#   Plain Debian i3lock (repo package, nothing compiled) showing a pre-rendered image:
#   the current wallpaper, smoothly blurred (no pixelation) and darkened, with
#   user@host and a hint in the theme colors. The image is cached in
#   ~/.cache/autobspwn/lock.png and rebuilt only when the wallpaper, the theme or the
#   screen layout change, so locking is instant.
#
#   lock.sh                 lock now
#   lock.sh --update [img]  (re)build the cached image (wallpaper.sh / theme-sync / install)
#   lock.sh --image         print the cached image path (building it if needed)
#
#   The image is rendered for the real monitor layout (xrandr); without X it uses
#   1920x1080 and gets rebuilt on the first lock. Needs ImageMagick (convert/magick);
#   without it the lock is a plain theme-colored i3lock. If i3lock is missing it
#   tries xsecurelock. Only ONE locker is ever started: if i3lock exits we never chain
#   into another locker (that is what made 3.1.0 look like it "rejected" the password).

# Colors follow the active theme-sync theme (fallback: amethyst)
BG="#1b1b22"; FG="#ececf4"; ACCENT="#9575cd"
_theme=$(tr -d '[:space:]' 2>/dev/null <"$HOME/.config/polybar/.current-theme" || true)
if [ -n "$_theme" ] && [ -f "$HOME/.config/bspwm/themes/$_theme.theme" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.config/bspwm/themes/$_theme.theme"
fi
hx() { printf '%s' "${1#\#}"; }

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/autobspwn"
IMG="$CACHE_DIR/lock.png"
META="$CACHE_DIR/lock.meta"
STYLE_VERSION=3

im() {
  if command -v magick >/dev/null 2>&1; then magick "$@"; else convert "$@"; fi
}
have_im() { command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; }

current_wall() {
  local wall=${1:-}
  if [ ! -f "$wall" ]; then
    wall=$(sed -n "s/.*--bg-[a-z]* *'\(.*\)'.*/\1/p" "$HOME/.fehbg" 2>/dev/null | head -n1)
  fi
  [ -f "$wall" ] || wall="$HOME/.config/bspwm/walls/cherry-field-mountains.jpg"
  [ -f "$wall" ] || wall=$(find "$HOME/.config/bspwm/walls" -maxdepth 1 -type f \
    \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \) 2>/dev/null | head -n1)
  printf '%s\n' "$wall"
}

# Monitor geometries "WxH+X+Y", one per line; root size on the first line as "WxH"
layout() {
  local root mons
  if [ -n "${DISPLAY:-}" ] && command -v xrandr >/dev/null 2>&1; then
    root=$(xrandr --current 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\),.*/\1x\2/p' | head -n1)
    mons=$(xrandr --listactivemonitors 2>/dev/null | awk 'NR>1 {
        split($3,a,"[/x+]"); printf "%sx%s+%s+%s\n", a[1], a[3], a[5], a[6] }')
  fi
  if [ -z "$root" ] && [ -n "${DISPLAY:-}" ] && command -v xdpyinfo >/dev/null 2>&1; then
    root=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2; exit}')
  fi
  [ -n "$root" ] || root=1920x1080
  [ -n "$mons" ] || mons="$root+0+0"
  printf '%s\n%s\n' "$root" "$mons"
}

font_file() {
  local f
  for q in "JetBrainsMono Nerd Font:style=Bold" "JetBrains Mono:style=Bold" "DejaVu Sans:style=Bold"; do
    f=$(fc-match -f '%{file}' "$q" 2>/dev/null || true)
    if [ -f "$f" ]; then printf '%s\n' "$f"; return 0; fi
  done
  return 1
}

meta_for() {
  local wall=$1 lay=$2 mt
  mt=$(stat -c %Y "$wall" 2>/dev/null || echo 0)
  printf 'v%s|%s|%s|%s|%s|%s|%s\n' "$STYLE_VERSION" "$wall" "$mt" "$(printf '%s' "$lay" | tr '\n' ' ')" "$BG" "$ACCENT" "$FG"
}

# Render one monitor-sized panel: cover-crop, smooth blur (downscale → blur → upscale),
# darken with the theme background, user@host + hint under the i3lock ring.
render_panel() { # wall W H out font
  local wall=$1 w=$2 h=$3 out=$4 font=$5 sw sh who ty hy fs1 fs2
  sw=$(( w / 4 )); sh=$(( h / 4 )); [ "$sw" -lt 64 ] && sw=64; [ "$sh" -lt 36 ] && sh=36
  who="$(id -un)@$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo localhost)"
  fs1=$(( h / 30 )); [ "$fs1" -lt 18 ] && fs1=18
  fs2=$(( h / 60 )); [ "$fs2" -lt 12 ] && fs2=12
  ty=$(( h / 2 + h / 7 + 10 )); [ "$ty" -lt $(( h / 2 + 130 )) ] && ty=$(( h / 2 + 130 ))
  hy=$(( ty + fs1 + fs2 ))
  local fontarg=()
  [ -n "$font" ] && fontarg=(-font "$font")
  im "${wall}[0]" -auto-orient -resize "${sw}x${sh}^" -gravity center -extent "${sw}x${sh}" \
    -blur 0x7 -resize "${w}x${h}!" -blur 0x4 \
    \( -size "${w}x${h}" "xc:${BG}" -alpha set -channel A -evaluate set 55% +channel \) -compose over -composite \
    \( -size "${w}x${h}" radial-gradient:none-"#000000" -alpha set -channel A -evaluate multiply 0.55 +channel \) -compose over -composite \
    -gravity north "${fontarg[@]}" \
    -fill "${FG}" -pointsize "$fs1" -annotate "+0+${ty}" "$who" \
    -fill "${FG}B0" -pointsize "$fs2" -annotate "+0+${hy}" "Escribe tu contraseña y pulsa Enter" \
    -fill "${ACCENT}" -draw "roundrectangle $(( w/2 - 40 )),$(( hy + fs2 + 14 )) $(( w/2 + 40 )),$(( hy + fs2 + 18 )) 2,2" \
    -depth 8 "$out"
}

build_image() { # [wallpaper]
  have_im || return 1
  local wall lay root mons font tmpd n=0 g w h x y args=()
  wall=$(current_wall "${1:-}")
  [ -f "$wall" ] || return 1
  lay=$(layout); root=$(printf '%s\n' "$lay" | head -n1); mons=$(printf '%s\n' "$lay" | tail -n +2)
  mkdir -p "$CACHE_DIR" || return 1
  font=$(font_file || true)
  tmpd=$(mktemp -d "$CACHE_DIR/.lock.XXXXXX") || return 1
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    w=${g%%x*}; h=${g#*x}; h=${h%%+*}; x=$(printf '%s' "$g" | cut -d+ -f2); y=$(printf '%s' "$g" | cut -d+ -f3)
    render_panel "$wall" "$w" "$h" "$tmpd/p$n.png" "$font" || { rm -rf "$tmpd"; return 1; }
    args+=( "$tmpd/p$n.png" -geometry "+$x+$y" -composite )
    n=$((n + 1))
  done <<<"$mons"
  if [ "$n" -eq 1 ] && [ "$mons" = "$root+0+0" ]; then
    mv -f "$tmpd/p0.png" "$IMG.tmp"
  else
    im -size "$root" "xc:${BG}" "${args[@]}" -depth 8 "png:$IMG.tmp" || { rm -rf "$tmpd"; return 1; }
  fi
  rm -rf "$tmpd"
  mv -f "$IMG.tmp" "$IMG" && meta_for "$wall" "$lay" >"$META"
}

# Rebuild only when something changed (cheap check: wallpaper path+mtime, layout, colors)
ensure_image() {
  local wall lay
  wall=$(current_wall "${1:-}"); lay=$(layout)
  if [ -s "$IMG" ] && [ "$(cat "$META" 2>/dev/null)" = "$(meta_for "$wall" "$lay")" ]; then
    return 0
  fi
  if command -v flock >/dev/null 2>&1; then
    mkdir -p "$CACHE_DIR"
    ( flock -w 20 9 || exit 1; build_image "$wall" ) 9>"$CACHE_DIR/.lock.flock"
  else
    build_image "$wall"
  fi
}

case "${1:-}" in
  --update) rm -f "$META"; ensure_image "${2:-}" >/dev/null 2>&1 || true; exit 0 ;;
  --image)  ensure_image "${2:-}" >/dev/null 2>&1 || true; [ -s "$IMG" ] && printf '%s\n' "$IMG"; exit 0 ;;
esac

# Already locked (double press / lock + suspend hook): do nothing
if pgrep -u "$(id -u)" -x i3lock >/dev/null 2>&1 || pgrep -u "$(id -u)" -x xsecurelock >/dev/null 2>&1; then
  exit 0
fi

# Notifications would draw over the lock screen: pause dunst while locked
paused=0
if command -v dunstctl >/dev/null 2>&1 && [ "$(dunstctl is-paused 2>/dev/null)" = false ]; then
  dunstctl set-paused true >/dev/null 2>&1 && paused=1
fi
# shellcheck disable=SC2329  # called by the EXIT trap
resume() { [ "$paused" = 1 ] && dunstctl set-paused false >/dev/null 2>&1; return 0; }
trap resume EXIT

if command -v i3lock >/dev/null 2>&1; then
  ensure_image >/dev/null 2>&1 || true
  # -n: stay in foreground (so dunst resumes after unlock) · -e: ignore empty Enter
  # -f: show the number of failed attempts · -c: color behind the image
  if [ -s "$IMG" ]; then
    i3lock -n -e -f -c "$(hx "$BG")" -i "$IMG"
  else
    i3lock -n -e -f -c "$(hx "$BG")"
  fi
elif command -v xsecurelock >/dev/null 2>&1; then
  XSECURELOCK_PASSWORD_PROMPT=asterisks XSECURELOCK_SHOW_USERNAME=1 XSECURELOCK_SHOW_HOSTNAME=1 \
    XSECURELOCK_FONT="${AUTOBSPWN_LOCK_FONT:-monospace:size=14}" xsecurelock
else
  notify-send -u critical AutoBSPWN "No hay bloqueador instalado: sudo apt install i3lock" 2>/dev/null || true
  exit 1
fi
exit 0
