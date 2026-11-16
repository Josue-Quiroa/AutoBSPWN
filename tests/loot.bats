#!/usr/bin/env bats
# loot ledger: move + clipboard + index.tsv (hora, etiqueta, herramienta, origen, sha256, archivo)
load test_helper

setup() {
  ab_setup
  focus 10.10.11.42
  L="$AUTOBSPWN_TARGETS/10.10.11.42/loot"
}

@test "file: moved into loot/, 0600, path copied, indexed with sha256" {
  echo 'Administrator:500:aad3b435:31d6cfe0:::' >"$BATS_TEST_TMPDIR/hashes.txt"
  sum=$(sha256sum "$BATS_TEST_TMPDIR/hashes.txt" | cut -d' ' -f1)
  run loot "NTLM admin" "$BATS_TEST_TMPDIR/hashes.txt"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/hashes.txt" ]
  [ -f "$L/hashes.txt" ]
  [ "$(stat -c %a "$L/hashes.txt")" = 600 ]
  [ "$(stat -c %a "$L")" = 700 ]
  [ "$(cat "$STUBS/clipboard")" = "$L/hashes.txt" ]
  line=$(tail -n1 "$L/index.tsv")
  [ "$(cut -f2 <<<"$line")" = "NTLM admin" ]
  [ "$(cut -f4 <<<"$line")" = "$BATS_TEST_TMPDIR/hashes.txt" ]
  [ "$(cut -f5 <<<"$line")" = "$sum" ]
  [ "$(cut -f6 <<<"$line")" = loot/hashes.txt ]
  grep -q $'\tloot\tNTLM admin' "$AUTOBSPWN_TARGETS/10.10.11.42/timeline.tsv"
}

@test "stdin: saved as <label>.txt, content copied, origin=stdin, never in the index" {
  run bash -c 'echo "svc_sql:S3cr3t!" | loot "sql creds"'
  [ "$status" -eq 0 ]
  [ "$(cat "$L/sql_creds.txt")" = 'svc_sql:S3cr3t!' ]
  [ "$(cat "$STUBS/clipboard")" = 'svc_sql:S3cr3t!' ]
  [ "$(tail -n1 "$L/index.tsv" | cut -f4)" = stdin ]
  run grep -q 'S3cr3t' "$L/index.tsv" "$AUTOBSPWN_TARGETS/10.10.11.42/timeline.tsv"
  [ "$status" -ne 0 ]
}

@test "tool: only the program name is recorded (arguments may hold passwords)" {
  echo x >"$BATS_TEST_TMPDIR/a.txt"
  loot -t "nxc smb 10.10.11.42 -u admin -p Passw0rd" smb "$BATS_TEST_TMPDIR/a.txt" >/dev/null
  [ "$(tail -n1 "$L/index.tsv" | cut -f3)" = nxc ]
  run grep -q Passw0rd "$L/index.tsv"
  [ "$status" -ne 0 ]
  echo y >"$BATS_TEST_TMPDIR/b.txt"
  AB_LAST_TOOL="secretsdump.py -hashes a:b corp/x@dc" loot dump "$BATS_TEST_TMPDIR/b.txt" >/dev/null
  [ "$(tail -n1 "$L/index.tsv" | cut -f3)" = secretsdump.py ]
  echo z >"$BATS_TEST_TMPDIR/c.txt"
  env -u AB_LAST_TOOL loot other "$BATS_TEST_TMPDIR/c.txt" >/dev/null
  [ "$(tail -n1 "$L/index.tsv" | cut -f3)" = manual ]
}

@test "name clash keeps both files; missing file / empty stdin / no target fail" {
  echo 1 >"$BATS_TEST_TMPDIR/k.txt"; loot a "$BATS_TEST_TMPDIR/k.txt" >/dev/null
  echo 2 >"$BATS_TEST_TMPDIR/k.txt"; loot b "$BATS_TEST_TMPDIR/k.txt" >/dev/null
  k=("$L"/k*); [ "${#k[@]}" -eq 2 ]
  run loot x "$BATS_TEST_TMPDIR/nope"
  [ "$status" -ne 0 ]
  run bash -c 'printf "" | loot empty'
  [ "$status" -ne 0 ]
  rm "$HOME/.config/bspwm/focus_ip"
  run loot x "$BATS_TEST_TMPDIR/k.txt"
  [ "$status" -eq 2 ]
}
