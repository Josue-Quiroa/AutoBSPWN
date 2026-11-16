#!/usr/bin/env bats
# tools-menu.sh --run: launches an installed tool without rofi
load test_helper

setup() {
  ab_setup
  for t in wireshark burpsuite msfconsole; do
    printf '#!/bin/sh\necho "%s $*" >>"%s/calls.log"\n' "$t" "$STUBS" >"$STUBS/$t"; chmod +x "$STUBS/$t"
  done
  # keep the test independent from the tools really installed on this machine
  export PATH="$STUBS:$REPO/scripts:/usr/bin:/bin"
}

@test "--run wireshark: GUI tool is detached with setsid" {
  run "$REPO/config/bspwm/scripts/tools-menu.sh" --run wireshark
  [ "$status" -eq 0 ]
  grep -q '^setsid -f wireshark$' "$STUBS/calls.log"
}

@test "--run burpsuite: Java GUI tools are launched too" {
  run "$REPO/config/bspwm/scripts/tools-menu.sh" --run burpsuite
  [ "$status" -eq 0 ]
  grep -q '^setsid -f burpsuite$' "$STUBS/calls.log"
}

@test "--run msfconsole: terminal tools open in a terminal" {
  run "$REPO/config/bspwm/scripts/tools-menu.sh" --run msfconsole
  [ "$status" -eq 0 ]
  sleep 0.2
  grep -q '^kitty --class floating bash -c' "$STUBS/calls.log"
  grep -q 'msfconsole' "$STUBS/calls.log"
}

@test "--run of a tool that is not installed fails with a notification" {
  run "$REPO/config/bspwm/scripts/tools-menu.sh" --run ghidra
  [ "$status" -eq 1 ]
  grep -q 'notify-send.*ghidra no está instalado' "$STUBS/calls.log"
}
