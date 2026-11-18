#!/usr/bin/env bats
# autobspwn-doctor: OK/WARN/FAIL report, exit codes, manifest and *.autobspwn-new checks
load test_helper

setup() {
  ab_setup
  rm -rf "$HOME/.config/bspwm/templates"
}

upd() { AUTOBSPWN_NO_RELOAD=1 DISPLAY='' bash "$REPO/Install.sh" --update; }
doc() { "$REPO/scripts/autobspwn-doctor" --no-color "$@"; }

@test "doctor: never uses sudo and reports a summary with a useful exit code" {
  printf '#!/bin/sh\necho "sudo $*" >>"%s/calls.log"; exit 1\n' "$STUBS" >"$STUBS/sudo"
  chmod +x "$STUBS/sudo"
  run doc
  [[ "$output" == *"Resumen:"* ]]
  [ "$status" -ge 0 ] && [ "$status" -le 2 ]
  run grep -q '^sudo' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
}

@test "doctor: missing core programs are FAIL (exit 2)" {
  run env PATH="$STUBS:/usr/bin:/bin" "$REPO/scripts/autobspwn-doctor" --no-color
  if command -v bspwm >/dev/null 2>&1; then skip "bspwm instalado en este sistema"; fi
  [ "$status" -eq 2 ]
  [[ "$output" == *"[FAIL] bspwm no está"* ]]
}

@test "doctor: deployed configs vs manifest, deleted files and pending .autobspwn-new" {
  run upd
  [ "$status" -eq 0 ]
  run doc
  [[ "$output" == *"archivos desplegados en su sitio"* ]]
  [[ "$output" == *"sin versiones nuevas pendientes"* ]]
  # edited by the user → INFO; deleted → WARN; pending new version → WARN
  echo '# mío' >>"$HOME/.config/sxhkd/sxhkdrc"
  rm "$HOME/.config/bspwm/scripts/calendar.sh"
  echo nuevo >"$HOME/.config/kitty/kitty.conf.autobspwn-new"
  run doc
  [ "$status" -ge 1 ]
  [[ "$output" == *"editado por ti"*"sxhkdrc"* ]]
  [[ "$output" == *"[WARN] falta ~/.config/bspwm/scripts/calendar.sh"* ]]
  [[ "$output" == *"[WARN] versión nueva sin revisar: ~/.config/kitty/kitty.conf.autobspwn-new"* ]]
}

@test "doctor --quiet prints only problems; old tmux is flagged" {
  printf '#!/bin/sh\necho "tmux 3.0a"\n' >"$STUBS/tmux"
  chmod +x "$STUBS/tmux"
  run doc --quiet
  [[ "$output" != *"[ OK ]"* ]]
  [[ "$output" == *"tmux 3.0a: el límite de 4 terminales"* ]]
}

@test "doctor: presentation mode and private ~/targets are reported" {
  mkdir -p "$HOME/.config/autobspwn" "$AUTOBSPWN_TARGETS"
  echo present=1 >"$HOME/.config/autobspwn/state"
  chmod 755 "$AUTOBSPWN_TARGETS"
  run doc
  [[ "$output" == *"[WARN] modo presentación ACTIVO"* ]]
  [[ "$output" == *"permisos 755"* ]]
}

@test "doctor: unknown option → 64" {
  run doc --nope
  [ "$status" -eq 64 ]
}
