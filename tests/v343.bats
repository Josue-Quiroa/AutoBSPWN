#!/usr/bin/env bats
# v3.4.3: VMware leaving 2-monitor / full-screen mode (2 → 1 monitor, same-monitor resize):
# which outputs count for bspwm, ghost monitors removed without losing windows, geometry fixed.
load test_helper

setup() {
  ab_setup
  M="$REPO/config/bspwm/scripts/monitors.sh"
  export AUTOBSPWN_GUEST_AGENT=vmware-user AB_MON_NOSLEEP=1 DISPLAY=:9
}

# xrandr stub printing $STUBS/xr.out
xr() { printf '#!/bin/sh\ncase "$*" in *--output*) echo "xrandr $*" >>"%s/calls.log"; exit 0 ;; esac\ncat "%s/xr.out"\n' "$STUBS" "$STUBS" >"$STUBS/xrandr"; chmod +x "$STUBS/xrandr"; cat >"$STUBS/xr.out"; }

# bspc stub: monitors / rectangles from $STUBS/bw ("name WxH+X+Y" lines), 2 desktops each
bw() {
  cat >"$STUBS/bw"
  cat >"$STUBS/bspc" <<'BS'
#!/bin/bash
d=$(dirname "$0"); echo "bspc $*" >>"$d/calls.log"
case "$*" in
  "query -M --names") cut -d' ' -f1 "$d/bw" ;;
  "query -T -m "*) g=$(awk -v m="$4" '$1 == m { print $2 }' "$d/bw"); [ -n "$g" ] || exit 1
     IFS='x+' read -r w h x y <<<"$g"
     echo "{\"padding\":{\"top\":0},\"rectangle\":{\"x\":$x,\"y\":$y,\"width\":$w,\"height\":$h}}" ;;
  "query -D -m "*) echo "0x${4//[^0-9]/}1"; echo "0x${4//[^0-9]/}2" ;;
esac
exit 0
BS
  chmod +x "$STUBS/bspc"
}

@test "VMware leaves Virtual-2 disconnected-but-lit / 0x0 / off-screen: not a monitor for bspwm" {
  xr <<'X'
Screen 0: minimum 1 x 1, current 2560 x 1440, maximum 8192 x 8192
Virtual-1 connected primary 2560x1440+0+0 0mm x 0mm
Virtual-2 disconnected 1920x1080+1920+0 0mm x 0mm
Virtual-3 connected 0x0+0+0 0mm x 0mm
Virtual-4 connected 1024x768+2560+0 0mm x 0mm
X
  run "$M" --status
  [[ "$output" == *$'== xrandr (activas)\nVirtual-1\t2560x1440+0+0\n== bspwm'* ]]
}

@test "2 → 1 monitor: ghost Virtual-2 desktops moved to Virtual-1 first, then removed; Virtual-1 resized" {
  xr <<'X'
Screen 0: minimum 1 x 1, current 2560 x 1440, maximum 8192 x 8192
Virtual-1 connected primary 2560x1440+0+0 0mm x 0mm
Virtual-2 disconnected 1920x1080+1920+0 0mm x 0mm
X
  bw <<'B'
Virtual-1 420x1080+0+0
Virtual-2 1920x1080+1920+0
B
  run "$M" --apply --no-bar
  [ "$status" -eq 0 ]
  grep -q 'bspc monitor Virtual-1 -g 2560x1440+0+0' "$STUBS/calls.log"
  grep -q 'bspc desktop 0x21 -m Virtual-1' "$STUBS/calls.log"
  grep -q 'bspc desktop 0x22 -m Virtual-1' "$STUBS/calls.log"
  grep -q 'bspc monitor Virtual-2 -r' "$STUBS/calls.log"
  [ "$(grep -n 'desktop 0x22 -m' "$STUBS/calls.log" | head -n1 | cut -d: -f1)" -lt "$(grep -n 'monitor Virtual-2 -r' "$STUBS/calls.log" | head -n1 | cut -d: -f1)" ]
  run grep -q 'bspc wm -a' "$STUBS/calls.log"            # never re-added (the v3.4.2 bug)
  [ "$status" -ne 0 ]
  run grep -q 'xrandr --output' "$STUBS/calls.log"       # VMware: xrandr left to vmware-user
  [ "$status" -ne 0 ]
}

@test "same monitor, new resolution (leaving full screen): only the geometry is fixed" {
  xr <<'X'
Screen 0: minimum 1 x 1, current 1680 x 1050, maximum 8192 x 8192
Virtual-1 connected primary 1680x1050+0+0 0mm x 0mm
X
  bw <<'B'
Virtual-1 2560x1440+0+0
B
  run "$M" --apply --no-bar
  grep -q 'bspc monitor Virtual-1 -g 1680x1050+0+0' "$STUBS/calls.log"
  run grep -qE 'monitor Virtual-1 -r|wm -a' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
}

@test "already in sync: nothing is touched; full apply repaints the wallpaper and relaunches polybar" {
  xr <<'X'
Screen 0: minimum 1 x 1, current 1920 x 1080, maximum 8192 x 8192
Virtual-1 connected primary 1920x1080+0+0 0mm x 0mm
X
  bw <<'B'
Virtual-1 1920x1080+0+0
B
  mkdir -p "$HOME/.config/polybar"
  printf '#!/bin/sh\necho "launch.sh" >>"%s/calls.log"\n' "$STUBS" >"$HOME/.config/polybar/launch.sh"
  chmod +x "$HOME/.config/polybar/launch.sh"
  printf 'echo fehbg >>"%s/calls.log"\n' "$STUBS" >"$HOME/.fehbg"
  printf '#!/bin/sh\n[ "$1" = -f ] && shift\nexec "$@"\n' >"$STUBS/setsid"; chmod +x "$STUBS/setsid"
  run "$M" --apply
  run grep -qE 'monitor .* -g|monitor .* -r|wm -a' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
  grep -qx fehbg "$STUBS/calls.log"
  grep -qx launch.sh "$STUBS/calls.log"
}

@test "bspwmrc keeps bspwm's own monitor clean-up on" {
  grep -q '^bspc config remove_disabled_monitors true' "$REPO/config/bspwm/bspwmrc"
  grep -q '^bspc config remove_unplugged_monitors true' "$REPO/config/bspwm/bspwmrc"
  grep -q '^bspc config merge_overlapping_monitors true' "$REPO/config/bspwm/bspwmrc"
}
