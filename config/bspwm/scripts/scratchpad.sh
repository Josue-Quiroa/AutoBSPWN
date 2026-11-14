#!/usr/bin/env bash
# AutoBSPWN v3.0.0 — toggle the scratchpad terminal (Super+u)
# Toggle the scratchterm window. xdotool IDs are decimal; bspc wants 0xhex.

node_id() {
  local dec hex
  dec=$(xdotool search --class scratchterm 2>/dev/null | tail -1)
  [ -n "$dec" ] || return 1
  hex=$(printf '0x%x' "$dec")
  if bspc query -N -n "$hex" >/dev/null 2>&1; then
    printf '%s\n' "$hex"
  elif bspc query -N -n "$dec" >/dev/null 2>&1; then
    printf '%s\n' "$dec"
  else
    # Window exists in X but not yet managed; return hex anyway
    printf '%s\n' "$hex"
  fi
}

wait_id() {
  local id
  for _ in $(seq 1 25); do
    id=$(node_id) && [ -n "$id" ] && { printf '%s\n' "$id"; return 0; }
    sleep 0.1
  done
  return 1
}

id=$(node_id || true)
if [ -z "$id" ]; then
  if command -v kitty >/dev/null 2>&1; then
    if command -v tmux >/dev/null 2>&1; then
      kitty --class scratchterm -e tmux new -A -s scratch &
    else
      kitty --class scratchterm &
    fi
  else
    notify-send AutoBSPWN "kitty no está instalado" 2>/dev/null || true
    exit 1
  fi
  id=$(wait_id) || exit 0
  bspc node "$id" -t floating -g sticky=on -g hidden=off -f 2>/dev/null || true
  exit 0
fi

if bspc query -N -n "${id}.hidden" >/dev/null 2>&1; then
  bspc node "$id" -g hidden=off -f
else
  bspc node "$id" -g hidden=on
fi
