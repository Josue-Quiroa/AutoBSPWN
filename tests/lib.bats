#!/usr/bin/env bats
# lib.sh helpers: IPs/CIDR math, host patterns, target dir, timeline, clipboard, real binaries
load test_helper

setup() {
  ab_setup
  # shellcheck source=/dev/null
  . "$AB_LIB"
}

@test "ab_is_ipv4 accepts valid and rejects invalid IPv4" {
  ab_is_ipv4 10.10.11.42
  ab_is_ipv4 0.0.0.0
  ab_is_ipv4 255.255.255.255
  run ab_is_ipv4 256.1.1.1;   [ "$status" -ne 0 ]
  run ab_is_ipv4 10.10.11;    [ "$status" -ne 0 ]
  run ab_is_ipv4 'a.b.c.d';   [ "$status" -ne 0 ]
  run ab_is_ipv4 '1.2.3.4; id'; [ "$status" -ne 0 ]
}

@test "ab_ip2int handles leading zeros as decimal" {
  [ "$(ab_ip2int 10.0.0.1)" = 167772161 ]
  [ "$(ab_ip2int 010.000.000.008)" = 167772168 ]
}

@test "ab_net_range: IP, CIDR, /0, last-octet range and wildcard" {
  [ "$(ab_net_range 10.0.0.5)" = "167772165 167772165" ]
  [ "$(ab_net_range 10.0.0.77/24)" = "167772160 167772415" ]
  [ "$(ab_net_range 0.0.0.0/0)" = "0 4294967295" ]
  [ "$(ab_net_range 10.0.0.5-20)" = "167772165 167772180" ]
  [ "$(ab_net_range '10.0.0.*')" = "167772160 167772415" ]
  run ab_net_range 10.0.0.0/33;   [ "$status" -ne 0 ]
  run ab_net_range 10.0.0.20-5;   [ "$status" -ne 0 ]
  run ab_net_range corp.local;    [ "$status" -ne 0 ]
}

@test "ab_host_match: exact (case-insensitive) and *.domain = subdomains only" {
  ab_host_match DC01.corp.local dc01.CORP.local
  ab_host_match a.b.corp.local '*.corp.local'
  run ab_host_match corp.local '*.corp.local';          [ "$status" -ne 0 ]
  run ab_host_match notcorp.local '*.corp.local';       [ "$status" -ne 0 ]
  run ab_host_match corp.local.evil.com '*.corp.local'; [ "$status" -ne 0 ]
}

@test "ab_target_dir creates 0700 dirs, notes and seeds scope.conf only if missing" {
  d=$(ab_target_dir 10.10.11.42)
  [ "$d" = "$AUTOBSPWN_TARGETS/10.10.11.42" ]
  [ -d "$d/nmap" ] && [ -d "$d/loot" ] && [ -d "$d/exploits" ] && [ -f "$d/notes.md" ]
  [ "$(stat -c %a "$AUTOBSPWN_TARGETS")" = 700 ]
  [ "$(stat -c %a "$d")" = 700 ]
  grep -q '^# in:' "$d/scope.conf"
  echo 'in: 10.0.0.0/8' >"$d/scope.conf"
  ab_target_dir 10.10.11.42 >/dev/null
  [ "$(cat "$d/scope.conf")" = 'in: 10.0.0.0/8' ]
}

@test "ab_timeline writes a header and sanitizes tabs/newlines" {
  ab_timeline 10.10.11.42 hud $'Copiar\tIP\nx'
  f="$AUTOBSPWN_TARGETS/10.10.11.42/timeline.tsv"
  [ "$(head -n1 "$f")" = $'# hora\tacción\tdetalle' ]
  [ "$(wc -l <"$f")" -eq 2 ]
  [ "$(tail -n1 "$f" | cut -f2-)" = $'hud\tCopiar IP x' ]
  # not an IP → ignored, no path tricks
  ab_timeline ../../etc hud x
  [ ! -e "$AUTOBSPWN_TARGETS/../../etc/timeline.tsv" ]
}

@test "ab_focus_ip / ab_focus_name read what setFocus writes" {
  run ab_focus_ip; [ "$status" -ne 0 ]
  setFocus 10.10.11.42 box.htb >/dev/null
  [ "$(ab_focus_ip)" = 10.10.11.42 ]
  [ "$(ab_focus_name)" = box.htb ]
}

@test "ab_copy goes to the clipboard (xclip)" {
  ab_copy 'secret value'
  [ "$(cat "$STUBS/clipboard")" = 'secret value' ]
}

@test "ab_real_bin skips the AutoBSPWN scope wrapper" {
  mkdir -p "$BATS_TEST_TMPDIR/w" "$BATS_TEST_TMPDIR/r"
  cp "$REPO/scripts/autobspwn-scope-wrapper" "$BATS_TEST_TMPDIR/w/nmap"
  printf '#!/bin/sh\necho real\n' >"$BATS_TEST_TMPDIR/r/nmap"; chmod +x "$BATS_TEST_TMPDIR/r/nmap"
  PATH="$BATS_TEST_TMPDIR/w:$BATS_TEST_TMPDIR/r:$PATH" run ab_real_bin nmap
  [ "$output" = "$BATS_TEST_TMPDIR/r/nmap" ]
}
