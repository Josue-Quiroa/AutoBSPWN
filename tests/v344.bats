#!/usr/bin/env bats
# v3.4.4: VMware / VirtualBox only switch 1 ↔ 2 screens when the mode really changes → "kick"
# (intermediate mode, then the target layout), once per transition, suppression window for the
# kick's own events, one apply at a time (flock), one watcher, never `bspc wm -r` automatically.
load test_helper

setup() {
  ab_setup
  M="$REPO/config/bspwm/scripts/monitors.sh"
  export AUTOBSPWN_GUEST_AGENT=vmware-user AB_MON_NOSLEEP=1 DISPLAY=:9
  for s in bspc pkill; do
    printf '#!/bin/sh\necho "%s $*" >>"%s/calls.log"\n' "$s" "$STUBS" >"$STUBS/$s"; chmod +x "$STUBS/$s"
  done
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/pgrep"; chmod +x "$STUBS/pgrep"       # "bspwm is running"
  # xrandr: prints $STUBS/xr.out (or xr.out.N on the N-th call when present); logs changes
  cat >"$STUBS/xrandr" <<'XR'
#!/bin/bash
d=$(dirname "$0")
case "$*" in *--output*) echo "xrandr $*" >>"$d/calls.log"; exit 0 ;; esac
n=$(( $(cat "$d/xr.n" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$d/xr.n"
if [ -f "$d/xr.out.$n" ]; then cat "$d/xr.out.$n"; else cat "$d/xr.out"; fi
XR
  chmod +x "$STUBS/xrandr"
}

# Josué's VM: two 1920x1080 host screens, VMware put Virtual1 at the window size
two_screens() {
  cat >"$STUBS/xr.out" <<'X'
Screen 0: minimum 1 x 1, current 1718 x 920, maximum 8192 x 8192
Virtual1 connected primary 1718x920+0+0 (normal left inverted right x axis y axis) 0mm x 0mm
   1920x1080     60.00 +
   1718x920      60.00*
   1600x900      59.95
   1280x720      60.00
Virtual2 connected (normal left inverted right x axis y axis) 0mm x 0mm
   1920x1080     60.00 +
   1600x900      59.95
X
}
kicks() { grep -c -- '--mode 1600x900$' "$STUBS/calls.log" || true; }

@test "1 → 2: intermediate mode, then Virtual1 primary + Virtual2 right-of at the preferred mode" {
  two_screens
  run "$M" --layout
  [ "${lines[0]}" = "primary Virtual1 1920x1080 1600x900" ]
  [ "${lines[2]}" = "right Virtual2 1920x1080" ]
  run "$M" --apply --no-bar
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$STUBS/calls.log")" = "xrandr --output Virtual1 --mode 1600x900" ]
  grep -qx 'xrandr --output Virtual1 --mode 1920x1080 --pos 0x0 --primary --output Virtual2 --mode 1920x1080 --right-of Virtual1' "$STUBS/calls.log"
}

@test "intermediate mode: 1600x900, else 1280x720, else any other; never the target or the current" {
  cat >"$STUBS/xr.out" <<'X'
Screen 0: minimum 1 x 1, current 1600 x 900, maximum 8192 x 8192
Virtual1 connected primary 1600x900+0+0 0mm x 0mm
   1600x900      60.00*+
   1280x720      60.00
   1024x768      60.00
X
  run "$M" --layout
  [ "${lines[0]}" = "primary Virtual1 1600x900 1280x720" ]
  sed -i '/1280x720/d' "$STUBS/xr.out"
  run "$M" --layout
  [ "${lines[0]}" = "primary Virtual1 1600x900 1024x768" ]
  sed -i '/1024x768/d' "$STUBS/xr.out"
  run "$M" --layout
  [ "${lines[0]}" = "primary Virtual1 1600x900 -" ]                # only one mode: no kick step
}

@test "target resolution: res= in the state or AUTOBSPWN_RES (if the output has it), else preferred, else 1920x1080" {
  two_screens
  mkdir -p "$HOME/.config/autobspwn"; echo res=1600x900 >"$HOME/.config/autobspwn/state"
  run "$M" --layout
  [ "${lines[0]}" = "primary Virtual1 1600x900 1280x720" ] && [ "${lines[2]}" = "right Virtual2 1600x900" ]
  AUTOBSPWN_RES=1280x720 run "$M" --layout
  [ "${lines[0]}" = "primary Virtual1 1280x720 1600x900" ]
  [ "${lines[2]}" = "right Virtual2 1920x1080" ]                    # Virtual2 has no 1280x720
  echo res=auto >"$HOME/.config/autobspwn/state"
  sed -i 's/ +$//' "$STUBS/xr.out"                                   # no preferred mode at all
  run "$M" --layout
  [ "${lines[0]}" = "primary Virtual1 1920x1080 1600x900" ]
}

@test "only once per transition: the same situation is not kicked again; a new one (2 → 1) is" {
  two_screens
  run "$M" --apply --no-bar
  run "$M" --apply --no-bar                       # VMware ignored it / fought back: no loop
  run "$M" --apply --no-bar
  [ "$(kicks)" -eq 1 ]
  cat >"$STUBS/xr.out" <<'X'
Screen 0: minimum 1 x 1, current 1920 x 1080, maximum 8192 x 8192
Virtual1 connected primary 1600x900+0+0 0mm x 0mm
   1920x1080     60.00 +
   1600x900      59.95*
   1280x720      60.00
Virtual2 disconnected 1920x1080+1920+0 0mm x 0mm
X
  run "$M" --apply --no-bar
  grep -q -- '--output Virtual1 --mode 1280x720$' "$STUBS/calls.log"      # current is 1600x900
  grep -qx 'xrandr --output Virtual1 --mode 1920x1080 --pos 0x0 --primary --output Virtual2 --off' "$STUBS/calls.log"
}

@test "already right: no kick; outside a VM: no kick; vm_kick=off: no kick; --fix always kicks" {
  cat >"$STUBS/xr.out" <<'X'
Screen 0: minimum 1 x 1, current 3840 x 1080, maximum 8192 x 8192
Virtual1 connected primary 1920x1080+0+0 0mm x 0mm
   1920x1080     60.00*+
   1600x900      59.95
Virtual2 connected 1920x1080+1920+0 0mm x 0mm
   1920x1080     60.00*+
X
  run "$M" --apply --no-bar
  run grep -q -- '--mode' "$STUBS/calls.log"; [ "$status" -ne 0 ]
  two_screens
  AUTOBSPWN_GUEST_AGENT='' AUTOBSPWN_VIRT=none run "$M" --apply --no-bar
  run grep -q -- '--mode' "$STUBS/calls.log"; [ "$status" -ne 0 ]
  mkdir -p "$HOME/.config/autobspwn"; echo vm_kick=off >"$HOME/.config/autobspwn/state"
  run "$M" --apply --no-bar
  run grep -q -- '--mode' "$STUBS/calls.log"; [ "$status" -ne 0 ]
  echo vm_kick=auto >"$HOME/.config/autobspwn/state"
  run "$M" --fix
  run "$M" --fix
  [ "$(kicks)" -eq 2 ]
}

@test "after an apply: sxhkd reloaded (USR1), never bspc wm -r; full apply relaunches bars + wallpaper" {
  two_screens
  mkdir -p "$HOME/.config/polybar"
  printf '#!/bin/sh\necho launch.sh >>"%s/calls.log"\n' "$STUBS" >"$HOME/.config/polybar/launch.sh"; chmod +x "$HOME/.config/polybar/launch.sh"
  printf 'echo fehbg >>"%s/calls.log"\n' "$STUBS" >"$HOME/.fehbg"
  printf '#!/bin/sh\n[ "$1" = -f ] && shift\nexec "$@"\n' >"$STUBS/setsid"; chmod +x "$STUBS/setsid"
  run "$M" --fix
  grep -q 'pkill -USR1 .*-x sxhkd' "$STUBS/calls.log"
  grep -qx fehbg "$STUBS/calls.log" && grep -qx launch.sh "$STUBS/calls.log"
  run grep -q 'bspc wm -r' "$STUBS/calls.log"; [ "$status" -ne 0 ]
  # and nowhere in the automatic code
  [ "$(grep -v '^[[:space:]]*#' "$M" | grep -c 'wm -r')" -eq 0 ]
}

@test "flock: an apply never overlaps another one (it waits, then skips)" {
  two_screens
  command -v flock >/dev/null || skip "sin flock"
  mkdir -p "$XDG_CACHE_HOME/autobspwn"
  flock "$XDG_CACHE_HOME/autobspwn/monitors-apply.lock" sleep 3 &
  sleep 0.3
  AB_MON_LOCK_WAIT=0 run "$M" --apply --no-bar
  [ "$status" -eq 0 ] && [[ "$output" == *"otro ajuste en curso"* ]]
  run grep -q 'xrandr' "$STUBS/calls.log"; [ "$status" -ne 0 ]
  wait
  run "$M" --apply --no-bar
  grep -q 'xrandr --output' "$STUBS/calls.log"
}

@test "watcher: ignores changes right after an apply (suppression), applies a real change once" {
  two_screens
  mkdir -p "$XDG_CACHE_HOME/autobspwn"
  date +%s >"$XDG_CACHE_HOME/autobspwn/monitors-applied"            # an apply just finished
  AB_MON_SUPPRESS=60 "$M" --watch >/dev/null 2>&1 3>&- &
  pid=$!
  sleep 0.5; sed -i 's/1718x920+0+0/1700x900+0+0/' "$STUBS/xr.out"; sleep 1
  kill "$pid"; wait "$pid" || true
  run grep -q -- '--mode' "$STUBS/calls.log"; [ "$status" -ne 0 ]
  two_screens; echo 0 >"$XDG_CACHE_HOME/autobspwn/monitors-applied"
  AB_MON_WATCH_ONCE=1 AB_MON_SUPPRESS=0 timeout 10 "$M" --watch >/dev/null 2>&1 3>&- &
  pid=$!
  sleep 0.5; sed -i 's/1718x920+0+0/1700x900+0+0/' "$STUBS/xr.out"
  wait "$pid"
  [ "$(kicks)" -eq 1 ]
}

@test "one watcher: a new one (bspwm reload) replaces the old one" {
  command -v flock >/dev/null || skip "sin flock"
  two_screens
  AB_MON_NOSLEEP=0 "$M" --watch >/dev/null 2>&1 3>&- &
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$XDG_CACHE_HOME/autobspwn/monitors-watch.pid" ] && break; sleep 0.2; done
  old=$(cat "$XDG_CACHE_HOME/autobspwn/monitors-watch.pid")
  AB_MON_NOSLEEP=0 "$M" --watch >/dev/null 2>&1 3>&- &
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    new=$(cat "$XDG_CACHE_HOME/autobspwn/monitors-watch.pid"); [ "$new" != "$old" ] && break; sleep 0.2
  done
  [ "$new" != "$old" ]
  sleep 0.3
  run kill -0 "$old"; [ "$status" -ne 0 ]
  kill "$new"; wait || true
}
