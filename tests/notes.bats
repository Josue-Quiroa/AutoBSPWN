#!/usr/bin/env bats
# quick-note.sh / note: one line to the target notes.md (timeline) or ~/notes/inbox.md
load test_helper

setup() { ab_setup; }
QN() { "$REPO/config/bspwm/scripts/quick-note.sh" "$@"; }

@test "no target → ~/notes/inbox.md with a timestamp" {
  run QN "revisar el puerto 8080"
  [ "$status" -eq 0 ]
  f="$HOME/notes/inbox.md"
  [ -f "$f" ]
  grep -Eq '^- \[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\] revisar el puerto 8080$' "$f"
  [ "$(stat -c %a "$HOME/notes")" = 700 ]
}

@test "active target → notes.md + timeline line without the text" {
  focus 10.10.11.5
  run QN "user: svc_backup"
  [ "$status" -eq 0 ]
  d="$AUTOBSPWN_TARGETS/10.10.11.5"
  tail -n1 "$d/notes.md" | grep -q 'user: svc_backup'
  grep -q $'\tnota\t' "$d/timeline.tsv"
  run grep -q 'svc_backup' "$d/timeline.tsv"
  [ "$status" -ne 0 ]
}

@test "hostile text and target name are written literally, never executed" {
  focus 10.10.11.5
  echo '$(touch /tmp/pwned_name)' >"$HOME/.config/bspwm/focus_name"
  run QN '$(touch "$HOME/pwned") `id` ; rm -rf ~'
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/pwned" ] && [ ! -e /tmp/pwned_name ]
  grep -qF '$(touch "$HOME/pwned") `id` ; rm -rf ~' "$AUTOBSPWN_TARGETS/10.10.11.5/notes.md"
}

@test "multi-line text becomes one line; empty text writes nothing" {
  run QN $'a\nb'
  grep -q '\] a b$' "$HOME/notes/inbox.md"
  n=$(wc -l <"$HOME/notes/inbox.md")
  run QN "   "
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$HOME/notes/inbox.md")" -eq "$n" ]
}

@test "popup: rofi answer is saved; cancel saves nothing" {
  printf '#!/bin/sh\ncat >/dev/null; echo "desde rofi"\n' >"$STUBS/rofi"; chmod +x "$STUBS/rofi"
  run QN
  grep -q 'desde rofi' "$HOME/notes/inbox.md"
  printf '#!/bin/sh\ncat >/dev/null; exit 1\n' >"$STUBS/rofi"
  n=$(wc -l <"$HOME/notes/inbox.md")
  run QN
  [ "$status" -eq 0 ] && [ "$(wc -l <"$HOME/notes/inbox.md")" -eq "$n" ]
}

@test "note CLI forwards to quick-note.sh" {
  run "$REPO/scripts/note" hola mundo
  [ "$status" -eq 0 ]
  grep -q '\] hola mundo$' "$HOME/notes/inbox.md"
}
