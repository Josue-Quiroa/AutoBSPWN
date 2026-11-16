#!/usr/bin/env bash
# AutoBSPWN v3.3.1 — toggle the scratchpad terminal (Super+u)
# Toggle the scratchterm window. xdotool IDs are decimal; bspc wants 0xhex.
#   scratchpad.sh            show / hide (starts it if needed)
#   scratchpad.sh --spawn    start it hidden (bspwmrc, at login)
# Inside: tmux session "scratch" on its OWN server (-L autobspwn-scratch) with
# ~/.config/autobspwn/scratch.tmux.conf → up to 4 terminals as tabs (Alt+1..4, Alt+←/→,
# Alt+n new, Alt+w close). Your ~/.tmux.conf and other tmux sessions are never touched.
SCRATCH_CONF="${AUTOBSPWN_SCRATCH_CONF:-$HOME/.config/autobspwn/scratch.tmux.conf}"
SCRATCH_SOCKET=autobspwn-scratch

# Command line that runs inside the scratch kitty
scratch_cmd() {
  if command -v tmux >/dev/null 2>&1; then
    if [ -r "$SCRATCH_CONF" ]; then
      printf '%s\0' tmux -L "$SCRATCH_SOCKET" -f "$SCRATCH_CONF" new -A -s scratch
    else
      # config missing (old install): still a separate server, plain tmux defaults
      printf '%s\0' tmux -L "$SCRATCH_SOCKET" -f /dev/null new -A -s scratch
    fi
  fi
}

spawn() {
  local -a cmd=()
  if ! command -v kitty >/dev/null 2>&1; then
    notify-send AutoBSPWN "kitty no está instalado" 2>/dev/null || true
    return 1
  fi
  mapfile -d '' -t cmd < <(scratch_cmd)
  if [ ${#cmd[@]} -gt 0 ]; then
    kitty --class scratchterm -e "${cmd[@]}" >/dev/null 2>&1 &
  else
    kitty --class scratchterm >/dev/null 2>&1 &
  fi
}

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

if [ "${1:-}" = --spawn ]; then
  # bspwmrc: start hidden (the bspwm rule for scratchterm sets hidden=on)
  node_id >/dev/null 2>&1 || spawn
  exit 0
fi

id=$(node_id || true)
if [ -z "$id" ]; then
  spawn || exit 1
  id=$(wait_id) || exit 0
  bspc node "$id" -t floating -g sticky=on -g hidden=off -f 2>/dev/null || true
  exit 0
fi

if bspc query -N -n "${id}.hidden" >/dev/null 2>&1; then
  bspc node "$id" -g hidden=off -f
else
  bspc node "$id" -g hidden=on
fi
