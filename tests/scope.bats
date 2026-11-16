#!/usr/bin/env bats
# PATH is changed per test on purpose (each @test runs in its own subshell)
# shellcheck disable=SC2030,SC2031
# Scope guard: scope.conf parsing, scope-check (in / out / exclusion / CIDR / wildcard),
# the nmap/ffuf wrappers and tscan's check.
load test_helper

setup() {
  ab_setup
  focus 10.10.11.42
  scope_for 10.10.11.42 <<'S'
# engagement
in: 10.10.11.0/24, 10.129.0.0/16
in: *.corp.local corp.local
out: 10.10.11.1  10.129.5.0/28
out: vpn.corp.local   # VPN appliance
this line is garbage
in: 999.1.1.1
S
  printf '10.10.11.77 web.htb\n10.200.0.9 dc01.corp.local dc01\n' >"$AB_HOSTS_FILE"
  # shellcheck source=/dev/null
  . "$AB_LIB"
}

check() { ab_scope_check "$1" >/dev/null; echo "$AB_SCOPE_STATUS"; }

@test "scope.conf parse: in/out lists, commas, comments, invalid entries" {
  ab_scope_load "$AUTOBSPWN_TARGETS/10.10.11.42/scope.conf"
  [ "${AB_SCOPE_IN[*]}" = "10.10.11.0/24 10.129.0.0/16 *.corp.local corp.local" ]
  [ "${AB_SCOPE_OUT[*]}" = "10.10.11.1 10.129.5.0/28 vpn.corp.local" ]
  [ "${#AB_SCOPE_BAD[@]}" -eq 2 ]
}

@test "scope.conf parse: *.domain is never glob-expanded" {
  cd "$BATS_TEST_TMPDIR"; touch a.corp.local b.corp.local
  ab_scope_load "$AUTOBSPWN_TARGETS/10.10.11.42/scope.conf"
  [[ " ${AB_SCOPE_IN[*]} " == *" *.corp.local "* ]]
}

@test "in scope: IP inside a CIDR" {
  [ "$(check 10.10.11.42)" = in-scope ]
  [ "$(check 10.10.11.255)" = in-scope ]
  [ "$(check 10.129.200.3)" = in-scope ]
}

@test "out of scope: IP in no in: rule" {
  [ "$(check 10.10.12.1)" = out-of-scope ]
  [ "$(check 8.8.8.8)" = out-of-scope ]
}

@test "exclusion wins over inclusion (IP and CIDR)" {
  [ "$(check 10.10.11.1)" = out-of-scope ]
  [ "$(check 10.129.5.3)" = out-of-scope ]
  [ "$(check 10.129.5.16)" = in-scope ]
}

@test "CIDR / range queries: inside, partly excluded, too wide" {
  [ "$(check 10.10.11.128/25)" = in-scope ]
  [ "$(check 10.10.11.0/24)" = out-of-scope ]     # contains the excluded .1
  [ "$(check 10.10.0.0/16)" = out-of-scope ]      # wider than the in: /24
  [ "$(check 10.10.11.5-20)" = in-scope ]
  [ "$(check 10.129.5.10-20)" = out-of-scope ]    # overlaps 10.129.5.0/28
}

@test "domain wildcards, apex, exclusions and look-alikes" {
  [ "$(check dc01.corp.local)" = in-scope ]
  [ "$(check APP.CORP.LOCAL)" = in-scope ]
  [ "$(check corp.local)" = in-scope ]
  [ "$(check vpn.corp.local)" = out-of-scope ]
  [ "$(check notcorp.local)" = out-of-scope ]
  [ "$(check corp.local.evil.com)" = out-of-scope ]
}

@test "hosts are mapped through /etc/hosts (no DNS)" {
  [ "$(check web.htb)" = in-scope ]                # 10.10.11.77
  printf '10.10.11.1 gw.htb\n' >>"$AB_HOSTS_FILE"
  [ "$(check gw.htb)" = out-of-scope ]             # its IP is excluded
}

@test "URLs, host:port and user@host are reduced to the host" {
  [ "$(check http://10.10.11.42:8080/login)" = in-scope ]
  [ "$(check https://app.corp.local/x?y=1)" = in-scope ]
  [ "$(check admin@10.10.11.9)" = in-scope ]
  [ "$(check http://vpn.corp.local/)" = out-of-scope ]
}

@test "no scope.conf / only comments → no-scope (exit 2); garbage → invalid (exit 3)" {
  rm "$HOME/.config/bspwm/focus_ip"
  run ab_scope_check 10.1.1.1
  [ "$status" -eq 2 ] && [ "$output" = no-scope ]
  focus 10.10.11.42
  printf '# in: 10.0.0.0/8\n' >"$AUTOBSPWN_TARGETS/10.10.11.42/scope.conf"
  run ab_scope_check 10.1.1.1
  [ "$status" -eq 2 ]
  run ab_scope_check '$(id)'
  [ "$status" -eq 3 ] && [ "$output" = invalid ]
}

@test "only out: rules → everything else is in scope" {
  printf 'out: 10.10.11.1\n' >"$AUTOBSPWN_TARGETS/10.10.11.42/scope.conf"
  [ "$(check 10.99.0.1)" = in-scope ]
  [ "$(check 10.10.11.1)" = out-of-scope ]
}

@test "AB_SCOPE_FILE overrides the active target's scope" {
  printf 'in: 192.168.0.0/16\n' >"$BATS_TEST_TMPDIR/other.conf"
  export AB_SCOPE_FILE="$BATS_TEST_TMPDIR/other.conf"
  [ "$(check 192.168.1.1)" = in-scope ]
  [ "$(check 10.10.11.42)" = out-of-scope ]
}

@test "scope-check CLI: output, -v reason and exit codes" {
  run "$REPO/scripts/scope-check" 10.10.11.42
  [ "$status" -eq 0 ] && [ "$output" = in-scope ]
  run "$REPO/scripts/scope-check" 10.10.11.1
  [ "$status" -eq 1 ] && [ "$output" = out-of-scope ]
  run "$REPO/scripts/scope-check" -v vpn.corp.local
  [ "$status" -eq 1 ]
  [[ "$output" == *"excluido por out: vpn.corp.local"* ]]
  run "$REPO/scripts/scope-check" 10.10.11.42 10.10.11.1
  [ "$status" -eq 1 ]
}

@test "scope-check is also a shell function once lib.sh is sourced" {
  run scope-check 10.10.11.1
  [ "$status" -eq 1 ] && [ "$output" = out-of-scope ]
}

@test "nmap wrapper blocks out-of-scope targets with a critical notification" {
  fake_nmap
  mkdir -p "$BATS_TEST_TMPDIR/w"; cp "$REPO/scripts/autobspwn-scope-wrapper" "$BATS_TEST_TMPDIR/w/nmap"
  export PATH="$BATS_TEST_TMPDIR/w:$PATH"
  run nmap -sV -p 80 10.10.11.1
  [ "$status" -eq 1 ]
  grep -q 'notify-send -u critical' "$STUBS/calls.log"
  run grep -q '^nmap ' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
  run nmap -sV -p 80 10.10.11.42 -oN out.txt
  [ "$status" -eq 0 ]
  grep -q '^nmap -sV -p 80 10.10.11.42 -oN out.txt$' "$STUBS/calls.log"
}

@test "nmap wrapper: option values are not targets, -iL is read, --force and opt-out work" {
  fake_nmap
  mkdir -p "$BATS_TEST_TMPDIR/w"; cp "$REPO/scripts/autobspwn-scope-wrapper" "$BATS_TEST_TMPDIR/w/nmap"
  export PATH="$BATS_TEST_TMPDIR/w:$PATH"
  run nmap -p 10.10.11.1 10.10.11.42          # 10.10.11.1 is the -p value here
  [ "$status" -eq 0 ]
  printf '10.10.11.5\n10.10.11.1 # gw\n' >"$BATS_TEST_TMPDIR/list"
  run nmap -iL "$BATS_TEST_TMPDIR/list"
  [ "$status" -eq 1 ]
  run nmap 10.10.11.1 --force
  [ "$status" -eq 0 ]
  grep -q '^nmap 10.10.11.1$' "$STUBS/calls.log"     # --force is not passed to nmap
  grep -q 'scope-force' "$AUTOBSPWN_TARGETS/10.10.11.1/timeline.tsv"
  AUTOBSPWN_SCOPE_GUARD=0 run nmap 10.10.12.9
  [ "$status" -eq 0 ]
}

@test "ffuf wrapper checks the -u host (FUZZ in the host = subdomain)" {
  printf '#!/bin/sh\necho "ffuf $*" >>"%s/calls.log"\n' "$STUBS" >"$STUBS/ffuf"; chmod +x "$STUBS/ffuf"
  mkdir -p "$BATS_TEST_TMPDIR/w"; cp "$REPO/scripts/autobspwn-scope-wrapper" "$BATS_TEST_TMPDIR/w/ffuf"
  export PATH="$BATS_TEST_TMPDIR/w:$PATH"
  run ffuf -u http://10.10.11.42/FUZZ -w words
  [ "$status" -eq 0 ]
  run ffuf -u http://FUZZ.corp.local/ -w words
  [ "$status" -eq 0 ]
  run ffuf -u https://vpn.corp.local/FUZZ -w words
  [ "$status" -eq 1 ]
}

@test "tscan refuses an out-of-scope target unless --force" {
  fake_nmap
  run tscan --no-sudo fast 10.10.11.1
  [ "$status" -eq 1 ]
  [[ "$output" == *"FUERA DE SCOPE"* ]]
  run grep -q '^nmap ' "$STUBS/calls.log"
  [ "$status" -ne 0 ]
  run tscan --no-sudo --force fast 10.10.11.1
  [ "$status" -eq 0 ]
}
