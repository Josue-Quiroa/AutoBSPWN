#!/usr/bin/env bats
# presentation mode, state file, HiDPI / multi-monitor logic
# shellcheck disable=SC1090
load test_helper

setup() {
  ab_setup
  for s in dunstctl bspc xrdb; do
    printf '#!/bin/sh\necho "%s $*" >>"%s/calls.log"\n' "$s" "$STUBS" >"$STUBS/$s"; chmod +x "$STUBS/$s"
  done
  PM="$REPO/config/bspwm/scripts/present-mode.sh"
  mkdir -p "$HOME/.config/polybar"
}

@test "state file: set / get / keep other keys / atomic" {
  . "$AB_LIB"
  [ "$(ab_state_get present 0)" = 0 ]
  ab_state_set present 1
  ab_state_set dpi 144
  ab_state_set present 0
  [ "$(ab_state_get present)" = 0 ] && [ "$(ab_state_get dpi)" = 144 ]
  [ "$(grep -c . "$AB_STATE")" -eq 2 ]
  run ab_state_set 'Bad Key' 1
  [ "$status" -ne 0 ]
  ab_state_set note $'a\nb'
  [ "$(ab_state_get note)" = "a b" ]
}

@test "toggle on/off: state persists, dunst paused/resumed, status exit code" {
  run "$PM" --status
  [ "$status" -eq 1 ] && [ "$output" = off ]
  run "$PM" --toggle
  [ "$status" -eq 0 ]
  grep -qx present=1 "$HOME/.config/autobspwn/state"
  grep -q 'dunstctl set-paused true' "$STUBS/calls.log"
  run "$PM" --status
  [ "$status" -eq 0 ] && [ "$output" = on ]
  run "$PM" --bar
  [[ "$output" == *"REC"* ]]
  run "$PM" --toggle
  grep -qx present=0 "$HOME/.config/autobspwn/state"
  grep -q 'dunstctl set-paused false' "$STUBS/calls.log"
  run "$PM" --bar
  [ -z "$output" ]
}

@test "presentation hides the target in the bar (and --copy does nothing)" {
  focus 10.10.11.5
  echo box.htb >"$HOME/.config/bspwm/focus_name"
  run bash "$REPO/config/polybar/scripts/focus_ip.sh"
  [[ "$output" == *10.10.11.5* ]]
  "$PM" --on
  run bash "$REPO/config/polybar/scripts/focus_ip.sh"
  [[ "$output" != *10.10.11.5* ]] && [[ "$output" != *box.htb* ]] && [[ "$output" == *oculto* ]]
  run bash "$REPO/config/polybar/scripts/focus_ip.sh" --copy
  [ ! -f "$STUBS/clipboard" ]
}

@test "presentation hides the LAN IP" {
  printf '#!/bin/sh\necho "1.1.1.1 via 10.0.2.2 dev eth0 src 10.0.2.15 uid 1000"\n' >"$STUBS/ip"; chmod +x "$STUBS/ip"
  run bash "$REPO/config/polybar/scripts/ethernet_status.sh"
  [[ "$output" == *10.0.2.15* ]]
  "$PM" --on
  run bash "$REPO/config/polybar/scripts/ethernet_status.sh"
  [[ "$output" != *10.0.2.15* ]] && [[ "$output" == *oculto* ]]
}

@test "--restore re-applies the saved state" {
  "$PM" --on; : >"$STUBS/calls.log"
  run "$PM" --restore
  grep -q 'dunstctl set-paused true' "$STUBS/calls.log"
}

@test "DPI from physical size, VM fallbacks and forced value" {
  . "$AB_LIB"
  [ "$(ab_calc_dpi 1920 527)" = 96 ]     # 24" 1080p
  [ "$(ab_calc_dpi 1920 344)" = 120 ]    # 15.6" 1080p laptop
  [ "$(ab_calc_dpi 2880 302)" = 192 ]    # 13" 3K
  [ "$(ab_calc_dpi 3840 600)" = 144 ]    # 27" 4K
  [ "$(ab_calc_dpi 1920 0)" = 96 ]       # VM: no size
  [ "$(ab_calc_dpi 3840 0)" = 192 ]      # VM 4K
  [ "$(ab_calc_dpi 1920 20)" = 96 ]      # nonsense size
  [ "$(ab_calc_dpi x y)" = 96 ]
  [ "$(ab_scale 30 144)" = 45 ] && [ "$(ab_scale 30 96)" = 30 ]
}

fake_xrandr() {
  cat >"$STUBS/xrandr" <<XR
#!/bin/sh
case "\$*" in *--output*) echo "xrandr \$*" >>"$STUBS/calls.log"; exit 0 ;; esac
cat <<'OUT'
Screen 0: minimum 320 x 200, current 4800 x 1800, maximum 16384 x 16384
eDP-1 connected primary 2880x1800+0+0 (normal left inverted right x axis y axis) 302mm x 189mm
   2880x1800     60.00*+
HDMI-1 connected 1920x1080+2880+0 (normal left inverted right x axis y axis) 527mm x 296mm
   1920x1080     60.00*+
DP-1 connected (normal left inverted right x axis y axis)
   2560x1440     59.95 +
DP-2 disconnected 1280x1024+4800+0 (normal left inverted right x axis y axis) 0mm x 0mm
OUT
XR
  chmod +x "$STUBS/xrandr"
}

@test "monitors.sh: per-output DPI, forced dpi, xrandr on/off for plugged/unplugged" {
  fake_xrandr
  M="$REPO/config/bspwm/scripts/monitors.sh"
  [ "$("$M" --dpi)" = 192 ]
  [ "$("$M" --dpi HDMI-1)" = 96 ]
  AUTOBSPWN_DPI=120 run "$M" --dpi
  [ "$output" = 120 ]
  . "$AB_LIB"; ab_state_set dpi 144
  [ "$("$M" --dpi HDMI-1)" = 144 ]
  ab_state_set dpi auto
  mkdir -p "$HOME/.config/rofi"
  DISPLAY=:9 run "$M" --apply --no-bar
  [ "$status" -eq 0 ]
  grep -q 'xrandr --output DP-2 --off' "$STUBS/calls.log"
  grep -q 'xrandr --output DP-1 --auto --right-of HDMI-1' "$STUBS/calls.log"
  grep -q 'dpi: 192' "$HOME/.config/rofi/dpi.rasi"
  ab_state_set xrandr off; : >"$STUBS/calls.log"
  DISPLAY=:9 run "$M" --apply --no-bar
  run grep -q 'xrandr --output' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
}

@test "desktops split across monitors (or I–X on each with desktops=each)" {
  . "$AB_LIB"
  [ "$(ab_split_desktops 1)" = "I II III IV V VI VII VIII IX X" ]
  [ "$(ab_split_desktops 2 | paste -sd'|' -)" = "I II III IV V|VI VII VIII IX X" ]
  [ "$(ab_split_desktops 3 | paste -sd'|' -)" = "I II III IV|V VI VII|VIII IX X" ]
  [ "$(ab_split_desktops 12 | wc -l)" -eq 12 ]
  cat >"$STUBS/bspc" <<BS
#!/bin/sh
echo "bspc \$*" >>"$STUBS/calls.log"
case "\$*" in "query -M --names") printf 'eDP-1\nHDMI-1\n' ;; esac
exit 0
BS
  chmod +x "$STUBS/bspc"
  run "$REPO/config/bspwm/scripts/monitors.sh" --desktops
  grep -q 'bspc monitor eDP-1 -d I II III IV V$' "$STUBS/calls.log"
  grep -q 'bspc monitor HDMI-1 -d VI VII VIII IX X$' "$STUBS/calls.log"
  ab_state_set desktops each; : >"$STUBS/calls.log"
  run "$REPO/config/bspwm/scripts/monitors.sh" --desktops
  [ "$(grep -c 'd I II III IV V VI VII VIII IX X$' "$STUBS/calls.log")" -eq 2 ]
}

@test "desktop.sh: global index when split, focused monitor when each" {
  D="$REPO/config/bspwm/scripts/desktop.sh"
  run "$D" focus 7
  grep -q "bspc desktop -f ^7" "$STUBS/calls.log"
  run "$D" send 10
  grep -q "bspc node -d ^10 --follow" "$STUBS/calls.log"
  mkdir -p "$HOME/.config/autobspwn"; echo desktops=each >"$HOME/.config/autobspwn/state"
  run "$D" focus 3
  grep -q "bspc desktop -f focused:^3" "$STUBS/calls.log"
  run "$D" focus 11
  [ "$status" -eq 2 ]
}
