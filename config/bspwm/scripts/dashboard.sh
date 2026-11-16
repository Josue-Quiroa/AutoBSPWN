#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — eww dashboard toggle (Super+F2 · Escape closes · right click on the power icon)
#   dashboard.sh            toggle      --open | --close | --status
# The eww daemon only lives while the dashboard is open (closing it kills the daemon).
# Without eww (not installed on this distro / old glibc) it shows a notification instead.
export PATH="$HOME/.local/bin:$PATH"
CFG="$HOME/.config/eww"
STATE="${XDG_RUNTIME_DIR:-/tmp}/autobspwn-dashboard.$(id -u)"

eww_bin() { command -v eww 2>/dev/null; }

is_open() { [ -e "$STATE" ] && [ -n "$(eww_bin)" ] && eww -c "$CFG" active-windows 2>/dev/null | grep -q '^dashboard'; }

do_close() {
  rm -f "$STATE"
  [ -n "$(eww_bin)" ] || exit 0
  eww -c "$CFG" close dashboard >/dev/null 2>&1
  eww -c "$CFG" kill >/dev/null 2>&1
  exit 0
}

do_open() {
  if [ -z "$(eww_bin)" ]; then
    notify-send -a AutoBSPWN -i dialog-information "Dashboard no disponible" \
      "eww no está instalado (se omite en esta distro). Reinstala con ./Install.sh o mira el README." 2>/dev/null || true
    exit 0
  fi
  [ -f "$CFG/eww.yuck" ] || { notify-send -a AutoBSPWN AutoBSPWN "Falta ~/.config/eww/eww.yuck" 2>/dev/null; exit 1; }
  # Dashboard follows the focused monitor
  local mon
  mon=$(bspc query -M -m focused --names 2>/dev/null | head -n1)
  eww -c "$CFG" ping >/dev/null 2>&1 || { eww -c "$CFG" daemon >/dev/null 2>&1; }
  for _ in $(seq 1 30); do eww -c "$CFG" ping >/dev/null 2>&1 && break; sleep 0.1; done
  if [ -n "$mon" ] && eww -c "$CFG" open dashboard --screen "$mon" >/dev/null 2>&1; then
    :
  else
    eww -c "$CFG" open dashboard >/dev/null 2>&1 || { notify-send -a AutoBSPWN AutoBSPWN "eww no pudo abrir el dashboard (eww logs)" 2>/dev/null; exit 1; }
  fi
  : >"$STATE"
}

case "${1:-}" in
  --close)  do_close ;;
  --open)   is_open || do_open ;;
  --status) if is_open; then echo open; else echo closed; fi ;;
  --escape) [ -e "$STATE" ] && do_close; exit 0 ;;
  *)        if is_open; then do_close; else do_open; fi ;;
esac
