#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — prefer fancy lockers; detect i3lock-color even when the binary is named i3lock.

# Colors follow the active theme-sync theme (fallback: mocha)
BG="#1e1e2e"; FG="#cdd6f4"; MUTED="#a6adc8"; ACCENT="#cba6f7"; ACCENT2="#89b4fa"
SUCCESS="#a6e3a1"; URGENT="#f38ba8"
_theme=$(tr -d '[:space:]' <"$HOME/.config/polybar/.current-theme" 2>/dev/null || true)
if [ -n "$_theme" ] && [ -f "$HOME/.config/bspwm/themes/$_theme.theme" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.config/bspwm/themes/$_theme.theme"
fi
hx() { printf '%s' "${1#\#}"; }

has_i3lock_color() {
  if command -v i3lock-color >/dev/null 2>&1; then
    return 0
  fi
  command -v i3lock >/dev/null 2>&1 || return 1
  i3lock --help 2>&1 | grep -q -- '--inside-color'
}

lock_color() {
  local bin=i3lock
  command -v i3lock-color >/dev/null 2>&1 && bin=i3lock-color
  "$bin" -c "$(hx "$BG")" \
    --inside-color="$(hx "$BG")cc" --ring-color="$(hx "$ACCENT")ff" \
    --keyhl-color="$(hx "$SUCCESS")ff" --bshl-color="$(hx "$URGENT")ff" \
    --line-color=00000000 --separator-color=00000000 \
    --insidever-color="$(hx "$ACCENT2")cc" --ringver-color="$(hx "$ACCENT2")ff" \
    --insidewrong-color="$(hx "$URGENT")cc" --ringwrong-color="$(hx "$URGENT")ff" \
    --clock --time-color="$(hx "$FG")ff" --date-color="$(hx "$MUTED")ff"
}

lock_blur() {
  command -v i3lock >/dev/null 2>&1 || return 1
  command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1 || return 1
  local tmp
  tmp=$(mktemp /tmp/autobspwn-lock.XXXXXX.png) || return 1
  if command -v scrot >/dev/null 2>&1; then
    scrot -z -o "$tmp" || { rm -f "$tmp"; return 1; }
  elif command -v import >/dev/null 2>&1; then
    import -window root "$tmp" || { rm -f "$tmp"; return 1; }
  else
    rm -f "$tmp"
    return 1
  fi
  if command -v magick >/dev/null 2>&1; then
    magick "$tmp" -scale 10% -scale 1000% "$tmp" || { rm -f "$tmp"; return 1; }
  else
    convert "$tmp" -scale 10% -scale 1000% "$tmp" || { rm -f "$tmp"; return 1; }
  fi
  i3lock -n -i "$tmp"
  local rc=$?
  rm -f "$tmp"
  return $rc
}

if command -v betterlockscreen >/dev/null 2>&1; then
  betterlockscreen -l dim
elif has_i3lock_color; then
  lock_color
elif lock_blur; then
  :
elif command -v i3lock >/dev/null 2>&1; then
  i3lock -c "$(hx "$BG")"
else
  notify-send AutoBSPWN "No hay locker instalado (i3lock)" 2>/dev/null || true
fi
