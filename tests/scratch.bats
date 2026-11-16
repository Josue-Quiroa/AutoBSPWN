#!/usr/bin/env bats
# Super+u scratchpad: dedicated tmux config (tabs, Alt keys) and the real max-4 limit
load test_helper

CONF="$REPO/config/autobspwn/scratch.tmux.conf"

setup() {
  ab_setup
  unset TMUX
  # short private socket dir (unix socket paths are length-limited)
  TMUX_TMPDIR=$(mktemp -d /tmp/abscratch.XXXXXX)
  export TMUX_TMPDIR
  T=(tmux -L autobspwn-scratch)
}

teardown() {
  if command -v tmux >/dev/null 2>&1; then "${T[@]}" kill-server 2>/dev/null || true; fi
  rm -rf "$TMUX_TMPDIR"
}

need_tmux() {
  command -v tmux >/dev/null 2>&1 || skip "tmux no instalado"
}

# scratch server with long-lived windows (no interactive shell needed)
start_scratch() {
  "${T[@]}" -f "$CONF" new -d -s scratch -x 120 -y 30 'sleep 300'
  "${T[@]}" set -g default-command 'sleep 300'
}

nwin() { "${T[@]}" display -p -t scratch '#{session_windows}'; }

@test "scratch.tmux.conf loads cleanly on its own server" {
  need_tmux
  run "${T[@]}" -f "$CONF" new -d -s scratch 'sleep 300'
  [ "$status" -eq 0 ] && [ -z "$output" ]
  [ "$("${T[@]}" show -gv status-position)" = bottom ]
  [ "$("${T[@]}" show -gv base-index)" = 1 ]
  [ "$("${T[@]}" show -gv @scratch_max)" = 4 ]
}

@test "Alt keys are bound without prefix" {
  need_tmux
  start_scratch
  keys=$("${T[@]}" list-keys -T root)
  for k in M-1 M-2 M-3 M-4 M-Left M-Right M-h M-l M-n M-w; do
    grep -Eq "^bind-key +-T root +$k " <<<"$keys"
  done
  # Ctrl+b stays the prefix
  [ "$("${T[@]}" show -gv prefix)" = C-b ]
}

@test "max 4 windows is enforced for any new-window (hook)" {
  need_tmux
  start_scratch
  for _ in 1 2 3 4 5 6; do "${T[@]}" new-window -t scratch; done
  [ "$(nwin)" -eq 4 ]
  # detached / inserted windows are removed too, the current one survives
  "${T[@]}" select-window -t scratch:2
  "${T[@]}" new-window -d -t scratch
  "${T[@]}" new-window -a -t scratch:1
  [ "$(nwin)" -eq 4 ]
  [ "$("${T[@]}" display -p -t scratch '#I')" = 2 ]
  # windows stay numbered 1..4 so Alt+1..4 match the tabs
  [ "$("${T[@]}" list-windows -t scratch -F '#I' | tr '\n' ' ')" = "1 2 3 4 " ]
  "${T[@]}" kill-window -t scratch:2
  [ "$("${T[@]}" list-windows -t scratch -F '#I' | tr '\n' ' ')" = "1 2 3 " ]
}

@test "Alt+n / Alt+1..4 / Alt+←→ / Alt+w with a real client" {
  need_tmux
  command -v script >/dev/null 2>&1 || skip "script(1) no disponible"
  start_scratch
  (sleep 20 2>/dev/null 3>&- | TERM=xterm script -qfc "tmux -L autobspwn-scratch attach -t scratch" /dev/null >/dev/null 2>&1 3>&- &)
  cl=
  for _ in $(seq 1 30); do
    cl=$("${T[@]}" list-clients -F '#{client_name}' 2>/dev/null | head -1)
    [ -n "$cl" ] && break
    sleep 0.1
  done
  [ -n "$cl" ] || skip "no se pudo adjuntar un cliente"
  "${T[@]}" send-keys -K -c "$cl" M-n 2>/dev/null || skip "tmux sin send-keys -K (< 3.4)"
  key() { "${T[@]}" send-keys -K -c "$cl" "$@"; sleep 0.15; }
  key M-n; key M-n; key M-n; key M-n
  [ "$(nwin)" -eq 4 ]
  key M-2
  [ "$("${T[@]}" display -p -t scratch '#I')" = 2 ]
  key M-Right
  [ "$("${T[@]}" display -p -t scratch '#I')" = 3 ]
  key M-h
  [ "$("${T[@]}" display -p -t scratch '#I')" = 2 ]
  key M-w
  [ "$(nwin)" -eq 3 ]
  key C-b c; key C-b c
  [ "$(nwin)" -eq 4 ]
  # Alt+w never closes the last terminal
  key M-w; key M-w; key M-w; key M-w
  [ "$(nwin)" -eq 1 ]
}

@test "scratchpad.sh starts kitty with the dedicated config on its own server" {
  printf '#!/bin/sh\nexit 1\n' >"$STUBS/xdotool"
  printf '#!/bin/sh\nexit 1\n' >"$STUBS/bspc"
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/tmux"
  chmod +x "$STUBS/xdotool" "$STUBS/bspc" "$STUBS/tmux"
  mkdir -p "$HOME/.config/autobspwn"
  cp "$CONF" "$HOME/.config/autobspwn/scratch.tmux.conf"
  run "$REPO/config/bspwm/scripts/scratchpad.sh" --spawn
  [ "$status" -eq 0 ]
  sleep 0.3
  grep -qx "kitty --class scratchterm -e tmux -L autobspwn-scratch -f $HOME/.config/autobspwn/scratch.tmux.conf new -A -s scratch" "$STUBS/calls.log"
  # config missing (old install) → still a separate server, never ~/.tmux.conf
  rm "$HOME/.config/autobspwn/scratch.tmux.conf" "$STUBS/calls.log"
  run "$REPO/config/bspwm/scripts/scratchpad.sh" --spawn
  sleep 0.3
  grep -qx "kitty --class scratchterm -e tmux -L autobspwn-scratch -f /dev/null new -A -s scratch" "$STUBS/calls.log"
}

@test "scratchpad.sh without kitty: notify and exit 1" {
  printf '#!/bin/sh\nexit 1\n' >"$STUBS/xdotool"
  chmod +x "$STUBS/xdotool"
  rm "$STUBS/kitty"
  PATH="/usr/bin:/bin" command -v kitty >/dev/null 2>&1 && skip "kitty instalado en el sistema"
  run env PATH="$STUBS:/usr/bin:/bin" "$REPO/config/bspwm/scripts/scratchpad.sh"
  [ "$status" -eq 1 ]
  grep -q "notify-send AutoBSPWN kitty no está instalado" "$STUBS/calls.log"
}

@test "Install.sh --update deploys scratch.tmux.conf and keeps your edits" {
  rm -rf "$HOME/.config/bspwm/templates"
  upd() { AUTOBSPWN_NO_RELOAD=1 DISPLAY='' bash "$REPO/Install.sh" --update; }
  run upd
  [ "$status" -eq 0 ]
  f="$HOME/.config/autobspwn/scratch.tmux.conf"
  cmp -s "$CONF" "$f"
  grep -q 'scratch.tmux.conf' "$HOME/.config/autobspwn/manifest.tsv"
  echo 'set -g @scratch_max 3' >>"$f"
  run upd
  [ "$status" -eq 0 ]
  grep -q '@scratch_max 3' "$f"
  [ -f "$f.autobspwn-new" ] && cmp -s "$CONF" "$f.autobspwn-new"
}
