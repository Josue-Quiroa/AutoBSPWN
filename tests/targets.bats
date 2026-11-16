#!/usr/bin/env bats
# targets.tsv parsing (targetFav), focus history merge and the menu's merged list
load test_helper

setup() {
  ab_setup
  F="$HOME/.config/bspwm/targets.tsv"
}

@test "targetFav init seeds the commented template; list ignores comments" {
  targetFav init
  grep -q '^# ' "$F"
  run targetFav list
  [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "targets.tsv parse: ip, name, tag; blank and comment lines skipped" {
  printf '# c\n\n10.10.11.42\tcertified.htb\tHTB · AD\n10.129.1.9\tsau\t\n  # indented comment\n' >"$F"
  run targetFav list
  [ "${lines[0]}" = $'10.10.11.42\tcertified.htb\tHTB · AD' ]
  [ "${lines[1]}" = $'10.129.1.9\tsau\t' ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "add dedups by IP and keeps comments; rm by name or IP" {
  targetFav init
  targetFav add 10.10.11.42 box1 first
  targetFav add 10.10.11.42 box1 second tag
  [ "$(targetFav list | grep -c '^10.10.11.42')" -eq 1 ]
  targetFav list | grep -q $'^10.10.11.42\tbox1\tsecond tag$'
  grep -q '^# ' "$F"
  targetFav rm box1
  run targetFav has 10.10.11.42
  [ "$status" -ne 0 ]
}

@test "add validates IP and name" {
  run targetFav add 300.1.1.1 x
  [ "$status" -ne 0 ]
  run targetFav add 10.1.1.1 'bad name;id'
  [ "$status" -ne 0 ]
}

@test "resolve: favorites first, then history; names case-insensitive" {
  printf '10.10.11.42\tcertified.htb\t\n' >"$F"
  printf '10.10.10.7\thistbox\n10.10.11.99\tcertified.htb\n' >"$HOME/.config/bspwm/focus_history"
  [ "$(targetFav resolve CERTIFIED.htb)" = $'10.10.11.42\tcertified.htb' ]
  [ "$(targetFav resolve histbox)" = $'10.10.10.7\thistbox' ]
  run targetFav resolve nope
  [ "$status" -ne 0 ]
}

@test "use → setFocus makes it the active target" {
  printf '10.10.11.42\tcertified.htb\t\n' >"$F"
  targetFav use certified.htb >/dev/null
  [ "$(cat "$HOME/.config/bspwm/focus_ip")" = 10.10.11.42 ]
  [ "$(cat "$HOME/.config/bspwm/focus_name")" = certified.htb ]
}

@test "target-menu --set lists saved targets (★) before history, without duplicates" {
  printf '10.10.11.42\tcertified.htb\tAD\n' >"$F"
  printf '10.10.11.42\tcertified.htb\n10.10.10.7\thistbox\n' >"$HOME/.config/bspwm/focus_history"
  # rofi stub: save the menu, pick nothing
  printf '#!/bin/sh\ncat >"%s/menu.txt"\nexit 1\n' "$STUBS" >"$STUBS/rofi"; chmod +x "$STUBS/rofi"
  run "$REPO/config/bspwm/scripts/target-menu.sh" --set
  [ "$(wc -l <"$STUBS/menu.txt")" -eq 2 ]
  head -n1 "$STUBS/menu.txt" | grep -q '10.10.11.42  certified.htb  · AD'
  tail -n1 "$STUBS/menu.txt" | grep -q '^  10.10.10.7  histbox$'
}
