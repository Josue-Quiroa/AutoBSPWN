#!/usr/bin/env bash
# Cache apt upgradable count (no sudo). Atomic write to avoid races.
# shellcheck source=/dev/null
. "$(dirname "$0")/libcolors.sh"
C=$HOME/.cache/autobspwn-updates
mkdir -p "$(dirname "$C")"
MAX=900
now=$(date +%s)
age=99999
if [ -f "$C" ]; then
  mtime=$(stat -c %Y "$C" 2>/dev/null || echo 0)
  [[ "$mtime" =~ ^[0-9]+$ ]] && age=$(( now - mtime ))
fi
if [ "$age" -ge "$MAX" ]; then
  count=$(LC_ALL=C apt list --upgradable 2>/dev/null | awk 'NR>1 && $0 !~ /^Listing/ && NF{c++} END{print c+0}')
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  tmp=$(mktemp "${C}.XXXXXX") && printf '%s\n' "$count" >"$tmp" && mv -f "$tmp" "$C" || rm -f "$tmp"
else
  count=$(cat "$C" 2>/dev/null || echo 0)
fi
[[ "$count" =~ ^[0-9]+$ ]] || count=0
if [ "$count" -gt 0 ]; then
  warn=$(polycolor warning '#fab387')
  echo "%{F$warn}󰏔%{F-} $count"
fi
