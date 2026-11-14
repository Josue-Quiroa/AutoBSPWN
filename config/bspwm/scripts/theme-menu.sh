#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — theme picker (rofi) → theme-sync --menu
# Usage: theme-menu.sh [--next|--prev]   (no args = rofi menu)
ts="$HOME/.local/bin/theme-sync"
[ -x "$ts" ] || ts=$(command -v theme-sync 2>/dev/null || true)
if [ -z "$ts" ]; then
  notify-send -a AutoBSPWN AutoBSPWN "theme-sync no está en ~/.local/bin" 2>/dev/null || true
  exit 1
fi
exec "$ts" "${1:---menu}"
