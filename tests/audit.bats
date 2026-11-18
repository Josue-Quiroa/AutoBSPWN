#!/usr/bin/env bats
# PATH is changed per test on purpose (each @test runs in its own subshell)
# shellcheck disable=SC2030,SC2031
# v3.4 audit fixes: scope bypasses, polybar tag injection, setFocus input, loot symlinks /
# binary output, symlinked dotfiles and backup pruning in Install.sh
load test_helper

setup() {
  ab_setup
  focus 10.10.11.42
  scope_for 10.10.11.42 <<'S'
in: 10.10.11.0/24
out: 10.10.11.1 10.10.11.200-210
S
  # shellcheck source=/dev/null
  . "$AB_LIB"
}

st() { ab_scope_check "$1" >/dev/null; echo "$AB_SCOPE_STATUS"; }

@test "nmap octet ranges / lists are judged by their bounding range" {
  [ "$(st 10.10.11.5-20)" = in-scope ]
  [ "$(st 10.10.11.2,3,50)" = in-scope ]
  [ "$(st 10.10.11.0-5)" = out-of-scope ]          # contains the excluded .1
  [ "$(st 10.10.11.205,7)" = out-of-scope ]
  [ "$(st 10.10.10-11.5)" = out-of-scope ]          # spills outside 10.10.11.0/24
  [ "$(st '10.10.11.*')" = out-of-scope ]           # includes .1
  [ "$(st 10.10.11.9-3)" = invalid ]
}

@test "leading zeros, numeric and hex spellings and IPv6 are not guessed: invalid" {
  for q in 010.010.011.005 0x0a0a0b05 0xa.0xa.0xb.0x5 168430341 10.10.11 fe80::1 '[fe80::1]:8080' 'http://[::1]/'; do
    [ "$(st "$q")" = invalid ]
  done
  ab_is_ipv4 10.10.11.0
  run ab_is_ipv4 10.10.011.5
  [ "$status" -ne 0 ]
}

@test "the guard blocks targets it can't evaluate while a scope is active (unless --force)" {
  run ab_scope_guard 0 nmap fe80::1
  [ "$status" -eq 1 ] && [[ "$output" == *"no verificable"* ]]
  run ab_scope_guard 1 nmap fe80::1
  [ "$status" -eq 0 ]
  rm "$AUTOBSPWN_TARGETS/10.10.11.42/scope.conf"
  run ab_scope_guard 0 nmap fe80::1                  # no scope → nothing is blocked
  [ "$status" -eq 0 ]
}

@test "nmap wrapper: -iL - (stdin) and unreadable lists are blocked; long lists fully read" {
  fake_nmap
  mkdir -p "$BATS_TEST_TMPDIR/w"; cp "$REPO/scripts/autobspwn-scope-wrapper" "$BATS_TEST_TMPDIR/w/nmap"
  export PATH="$BATS_TEST_TMPDIR/w:$PATH"
  run nmap -iL - <<<"10.10.11.1"
  [ "$status" -eq 1 ]
  run nmap -iL /nonexistent
  [ "$status" -eq 1 ]
  { for i in $(seq 1 2100); do echo 10.10.11.5; done; echo 10.10.11.1; } >"$BATS_TEST_TMPDIR/big"
  run nmap -iL "$BATS_TEST_TMPDIR/big"
  [ "$status" -eq 1 ]                                 # line 2101 is out of scope
  run nmap --stats-every 5s 10.10.11.42               # option value is not a target
  [ "$status" -eq 0 ]
}

@test "polybar: a hostile target name can't add %{A…} actions; bad IP file is not echoed" {
  mkdir -p "$HOME/.config/bspwm"
  printf '%%{A1:touch /tmp/x:}x%%{A}\n' >"$HOME/.config/bspwm/focus_name"
  run bash "$REPO/config/polybar/scripts/focus_ip.sh"
  [[ "$output" != *"%{A"* ]]
  echo '%{A1:reboot:}' >"$HOME/.config/bspwm/focus_ip"
  run bash "$REPO/config/polybar/scripts/focus_ip.sh"
  [[ "$output" != *"%{A1"* ]] && [[ "$output" == *"IP inválida"* ]]
}

@test "setFocus: no leading zeros, name kept on one line, no copy-paste tip for odd names" {
  run "$REPO/scripts/setFocus" 010.10.11.5 box
  [ "$status" -eq 1 ]
  run "$REPO/scripts/setFocus" 10.10.11.5 $'a\tb\nc'
  [ "$status" -eq 0 ]
  [ "$(awk -F'\t' 'NR==1{print NF}' "$HOME/.config/bspwm/focus_history")" -eq 2 ]
  run "$REPO/scripts/setFocus" 10.10.11.6 "x'; rm -rf ~; echo '"
  [[ "$output" != *"Tip:"* ]]
}

@test "loot: a symlink is saved as a real 0600 copy, the original is untouched" {
  echo secreto >"$BATS_TEST_TMPDIR/orig"; chmod 644 "$BATS_TEST_TMPDIR/orig"
  ln -s "$BATS_TEST_TMPDIR/orig" "$BATS_TEST_TMPDIR/lnk"
  run "$REPO/scripts/loot" creds "$BATS_TEST_TMPDIR/lnk"
  [ "$status" -eq 0 ]
  f="$AUTOBSPWN_TARGETS/10.10.11.42/loot/lnk"
  [ -f "$f" ] && [ ! -L "$f" ] && [ "$(stat -c %a "$f")" = 600 ]
  [ "$(stat -c %a "$BATS_TEST_TMPDIR/orig")" = 644 ] && [ -L "$BATS_TEST_TMPDIR/lnk" ]
}

@test "loot: big or binary stdin → the clipboard gets the path, not the content" {
  printf 'a\0b' | "$REPO/scripts/loot" bin
  [[ "$(cat "$STUBS/clipboard")" == */loot/bin.txt ]]
  head -c 70000 /dev/zero | tr '\0' A | "$REPO/scripts/loot" big
  [[ "$(cat "$STUBS/clipboard")" == */loot/big.txt ]]
  echo hola | "$REPO/scripts/loot" small
  [ "$(cat "$STUBS/clipboard")" = hola ]
}

@test "Install.sh: a symlinked dotfile is never written through; backups keep its content" {
  rm -rf "$HOME/.config/bspwm/templates"
  mkdir -p "$HOME/dots"; echo '# mi zshrc (stow)' >"$HOME/dots/zshrc"
  ln -s "$HOME/dots/zshrc" "$HOME/.zshrc"
  run env AUTOBSPWN_NO_RELOAD=1 DISPLAY='' bash "$REPO/Install.sh" --update
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/dots/zshrc")" = '# mi zshrc (stow)' ] && [ -L "$HOME/.zshrc" ]
  [ -f "$HOME/.zshrc.autobspwn-new" ]
  run env AUTOBSPWN_NO_RELOAD=1 DISPLAY='' bash "$REPO/Install.sh" --update
  b=("$HOME"/.config/autobspwn-backup-*)
  last=${b[-1]}
  [ ! -L "$last/.zshrc" ] && [ "$(cat "$last/.zshrc")" = '# mi zshrc (stow)' ]
}

@test "Install.sh keeps only the newest AUTOBSPWN_KEEP_BACKUPS backups" {
  rm -rf "$HOME/.config/bspwm/templates"
  for i in 01 02 03 04 05; do mkdir -p "$HOME/.config/autobspwn-backup-20200101-0000$i"; done
  run env AUTOBSPWN_NO_RELOAD=1 DISPLAY='' AUTOBSPWN_KEEP_BACKUPS=3 bash "$REPO/Install.sh" --update
  [ "$status" -eq 0 ]
  b=("$HOME"/.config/autobspwn-backup-*)
  [ "${#b[@]}" -eq 3 ]
  [ -d "$HOME/.config/autobspwn-backup-20200101-000005" ]
  [ ! -d "$HOME/.config/autobspwn-backup-20200101-000001" ]
}
