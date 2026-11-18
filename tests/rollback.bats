#!/usr/bin/env bats
# autobspwn-update --list-backups / --rollback: restores the dotfiles from before an update
load test_helper

setup() {
  ab_setup
  rm -rf "$HOME/.config/bspwm/templates"
  # a private copy of the repo so a "new version" can be simulated
  R="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$R"
  (cd "$REPO" && tar cf - --exclude=.git --exclude=tests . ) | (cd "$R" && tar xf -)
  export AUTOBSPWN_NO_RELOAD=1 DISPLAY=''
}

upd() { bash "$R/Install.sh" --update; }
au() { "$REPO/scripts/autobspwn-update" "$@"; }

@test "no backups → list says so (exit 1); rollback fails cleanly" {
  run au --list-backups
  [ "$status" -eq 1 ] && [[ "$output" == *"No hay backups"* ]]
  run au --rollback
  [ "$status" -eq 1 ]
}

@test "rollback restores the files an update changed, keeps your targets, and is idempotent" {
  run upd; [ "$status" -eq 0 ]
  sleep 1
  echo "# AutoBSPWN NEXT" >>"$R/config/kitty/kitty.conf"     # the "new release"
  run upd; [ "$status" -eq 0 ]
  grep -q 'AutoBSPWN NEXT' "$HOME/.config/kitty/kitty.conf"
  echo 10.10.11.9 >"$HOME/.config/bspwm/focus_ip"            # your data after the update
  printf '10.10.11.9\tbox\n' >"$HOME/.config/bspwm/targets.tsv"
  run au --list-backups
  [ "$status" -eq 0 ] && [[ "$output" == *"autobspwn-backup-"* ]]
  run au --rollback
  [ "$status" -eq 0 ]
  [[ "$output" == *"archivos restaurados"* ]]
  run grep -q 'AutoBSPWN NEXT' "$HOME/.config/kitty/kitty.conf"
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.config/bspwm/focus_ip")" = 10.10.11.9 ]
  [ -f "$HOME/.config/bspwm/targets.tsv" ]
  # what was there is saved in a -rollback snapshot
  snap=("$HOME"/.config/autobspwn-backup-*-rollback)
  grep -q 'AutoBSPWN NEXT' "${snap[0]}/kitty/kitty.conf"
  # again: nothing to do
  run au --rollback
  [ "$status" -eq 0 ] && [[ "$output" == *"Nada que restaurar"* ]]
  # and the snapshot brings the update back
  run au --rollback "${snap[0]##*/}"
  [ "$status" -eq 0 ]
  grep -q 'AutoBSPWN NEXT' "$HOME/.config/kitty/kitty.conf"
}

@test "rollback by number and bad picks" {
  run upd; [ "$status" -eq 0 ]
  run au --rollback 99
  [ "$status" -eq 1 ] && [[ "$output" == *"número 99"* ]]
  run au --rollback ../../etc
  [ "$status" -eq 1 ]
  run au --rollback 1
  [ "$status" -eq 0 ]
}
