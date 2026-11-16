#!/usr/bin/env bats
# tscan: profiles, result files, ports.txt merge and "new ports" summary
load test_helper

setup() {
  ab_setup
  fake_nmap
  focus 10.10.11.42
  D="$AUTOBSPWN_TARGETS/10.10.11.42"
}

@test "fast: writes nmap/fast-<ts>.*, ports.txt and ports.tsv; notifies new ports" {
  FAKE_PORTS="22/tcp/ssh 80/tcp/http" run tscan --no-sudo fast
  [ "$status" -eq 0 ]
  ls "$D"/nmap/fast-*.gnmap "$D"/nmap/fast-*.xml "$D"/nmap/fast-*.nmap
  [ "$(cat "$D/ports.txt")" = 22,80 ]
  [[ "$output" == *"NUEVOS: 22/tcp (ssh), 80/tcp (http)"* ]]
  grep -q 'notify-send.*NUEVOS' "$STUBS/calls.log"
  grep -q $'^22/tcp\tssh\t' "$D/nmap/ports.tsv"
}

@test "dedup against previous scans: only really new ports are reported, ports.txt is the union" {
  FAKE_PORTS="22/tcp/ssh 80/tcp/http" tscan --no-sudo fast >/dev/null
  FAKE_PORTS="22/tcp/ssh 445/tcp/microsoft-ds" run tscan --no-sudo fast
  [[ "$output" == *"2 abiertos · NUEVOS: 445/tcp (microsoft-ds)"* ]]
  [ "$(cat "$D/ports.txt")" = 22,80,445 ]
  FAKE_PORTS="22/tcp/ssh" run tscan --no-sudo fast
  [[ "$output" == *"ninguno nuevo"* ]]
  g=("$D"/nmap/fast-*.gnmap); [ "${#g[@]}" -eq 3 ]   # same second → no overwrite
}

@test "ports.txt written by older versions counts as known" {
  mkdir -p "$D"; echo 22,8080 >"$D/ports.txt"
  FAKE_PORTS="22/tcp/ssh 8080/tcp/http-proxy 3389/tcp/ms-wbt-server" run tscan --no-sudo fast
  [[ "$output" == *"NUEVOS: 3389/tcp (ms-wbt-server)"* ]]
  [ "$(cat "$D/ports.txt")" = 22,3389,8080 ]
}

@test "full: -p- then -sC -sV only on the open ports" {
  FAKE_PORTS="22/tcp/ssh 5985/tcp/wsman" run tscan --no-sudo full
  [ "$status" -eq 0 ]
  grep -q '^nmap -sT -p- ' "$STUBS/calls.log"
  grep -q '^nmap -sT -sC -sV -p 22,5985 ' "$STUBS/calls.log"
  ls "$D"/nmap/full-*-svc.gnmap
}

@test "ad: AD ports and scripts; udp needs root" {
  FAKE_PORTS="88/tcp/kerberos-sec 389/tcp/ldap" run tscan --no-sudo ad
  [ "$status" -eq 0 ]
  grep -q -- '-p 53,88,135,139,389,445' "$STUBS/calls.log"
  grep -q -- "--script default,ldap-rootdse" "$STUBS/calls.log"
  run tscan --no-sudo udp
  [ "$status" -eq 1 ]
}

@test "timeline gets start and end lines; bad input is rejected" {
  FAKE_PORTS="22/tcp/ssh" tscan --no-sudo fast >/dev/null
  [ "$(grep -c 'tscan fast' "$D/timeline.tsv")" -eq 2 ]
  run tscan --no-sudo fast 10.10.11.300
  [ "$status" -eq 2 ]
  run tscan --no-sudo nope
  [ "$status" -eq 2 ]
}
