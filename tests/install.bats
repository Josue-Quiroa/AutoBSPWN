#!/usr/bin/env bats
# Install.sh: --list-tools, --update (config-only, idempotent, keeps edits), syntax of everything
load test_helper

setup() {
  ab_setup
  rm -rf "$HOME/.config/bspwm/templates"
}

upd() { AUTOBSPWN_NO_RELOAD=1 DISPLAY='' bash "$REPO/Install.sh" --update; }

@test "--version and --list-tools exit 0" {
  run bash "$REPO/Install.sh" --version
  [ "$status" -eq 0 ] && [[ "$output" == "AutoBSPWN $(cat "$REPO/VERSION")" ]]
  run bash "$REPO/Install.sh" --list-tools
  [ "$status" -eq 0 ]
}

@test "--update deploys configs and commands without apt" {
  run upd
  [ "$status" -eq 0 ]
  [[ "$output" == *"sincronizado"* ]]
  for b in setFocus targetFav theme-sync scope-check tscan loot autobspwn-update nmap ffuf; do
    [ -x "$HOME/.local/bin/$b" ]
  done
  [ -f "$HOME/.config/bspwm/targets.tsv" ] && [ -f "$HOME/.config/bspwm/target-commands.conf" ]
  [ -f "$HOME/.config/bspwm/templates/scope.conf" ]
  [ "$(cat "$HOME/.config/autobspwn/repo")" = "$REPO" ]
  [ -s "$HOME/.config/autobspwn/manifest.tsv" ]
}

@test "--update is idempotent and keeps files you edited (.autobspwn-new next to them)" {
  upd >/dev/null
  echo '# mío' >>"$HOME/.config/sxhkd/sxhkdrc"
  echo 'Ping | ping -c1 {ip}' >>"$HOME/.config/bspwm/target-commands.conf"
  run upd
  [ "$status" -eq 0 ]
  [ "$(tail -n1 "$HOME/.config/sxhkd/sxhkdrc")" = '# mío' ]
  [ -f "$HOME/.config/sxhkd/sxhkdrc.autobspwn-new" ]
  [[ "$output" == *"Conservado tu ~/.config/sxhkd/sxhkdrc"* ]]
  [ "$(tail -n1 "$HOME/.config/bspwm/target-commands.conf")" = 'Ping | ping -c1 {ip}' ]
  # a file you did not touch is still updated silently
  [[ "$output" != *"bspwmrc"* ]]
}

@test "--update keeps the user's theme" {
  upd >/dev/null
  "$HOME/.local/bin/theme-sync" --no-reload nord >/dev/null
  run upd
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.config/polybar/.current-theme")" = nord ]
  [[ "$output" != *"colors.ini"* ]]
}

@test "autobspwn-update without a clone explains how to clone" {
  run env -u AUTOBSPWN_REPO HOME="$HOME" "$REPO/scripts/autobspwn-update" --where --repo /nonexistent
  [ "$status" -eq 1 ]
  [[ "$output" == *"git clone https://github.com/Josue-Quiroa/AutoBSPWN"* ]]
  run env HOME="$HOME" "$REPO/scripts/autobspwn-update" --where --repo "$REPO"
  [ "$status" -eq 0 ] && [ "$output" = "$REPO" ]
}

@test "every shell script passes bash -n" {
  while IFS= read -r f; do
    bash -n "$f" || { echo "bash -n failed: $f"; return 1; }
  done < <(cd "$REPO" && { echo Install.sh; find config scripts tests -path tests/vendor -prune -o -type f -print; } \
            | while read -r g; do head -n1 "$REPO/$g" | grep -qE '^#!.*\b(ba)?sh\b' && echo "$REPO/$g"; done)
}
