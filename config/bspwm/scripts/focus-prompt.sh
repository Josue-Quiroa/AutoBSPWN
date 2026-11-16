#!/usr/bin/env bash
# AutoBSPWN v3.3.0 — interactive setFocus prompt (Super+Shift+i / polybar)
setfocus_bin="${HOME}/.local/bin/setFocus"
[ -x "$setfocus_bin" ] || setfocus_bin="$(command -v setFocus 2>/dev/null || true)"
if [ -z "$setfocus_bin" ]; then
  printf 'setFocus no está instalado en ~/.local/bin\n'
  read -r -n 1 -p "Enter para cerrar..." _
  exit 1
fi
read -r -p "Focus IP: " ip || exit 0
[ -n "$ip" ] || exit 0
read -r -p "Nombre (opcional): " name || true
if [ -n "$name" ]; then
  "$setfocus_bin" "$ip" "$name"
else
  "$setfocus_bin" "$ip"
fi
sleep 0.3
