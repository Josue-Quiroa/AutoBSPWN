# shellcheck shell=bash
# Shared setup for the AutoBSPWN bats suite: a throw-away $HOME, stub binaries that only
# log (notify-send, xclip, rofi, setsid, kitty), and lib.sh from the repo (not ~/.config).
REPO="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export REPO

ab_setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export AUTOBSPWN_TARGETS="$HOME/targets"
  export AB_LIB="$REPO/config/bspwm/scripts/lib.sh"
  export AB_HOSTS_FILE="$BATS_TEST_TMPDIR/hosts"
  export XDG_CACHE_HOME="$HOME/.cache"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  export STUBS
  mkdir -p "$HOME/.config/bspwm/templates" "$STUBS"
  cp "$REPO/config/bspwm/templates/"* "$HOME/.config/bspwm/templates/"
  : >"$AB_HOSTS_FILE"
  local s
  for s in notify-send xclip xsel setsid kitty; do
    printf '#!/bin/sh\necho "%s $*" >>"%s/calls.log"\n' "$s" "$STUBS" >"$STUBS/$s"
    chmod +x "$STUBS/$s"
  done
  # xclip also keeps what was copied
  printf '#!/bin/sh\ncat >"%s/clipboard"\necho "xclip $*" >>"%s/calls.log"\n' "$STUBS" "$STUBS" >"$STUBS/xclip"
  export PATH="$STUBS:$REPO/scripts:$PATH"
}

# set the active target
focus() { printf '%s\n' "$1" >"$HOME/.config/bspwm/focus_ip"; }

# write ~/targets/<ip>/scope.conf from stdin
scope_for() { mkdir -p "$AUTOBSPWN_TARGETS/$1"; cat >"$AUTOBSPWN_TARGETS/$1/scope.conf"; }

# fake nmap: writes -oA <base>.{nmap,gnmap,xml} with $FAKE_PORTS ("22/tcp/ssh 80/tcp/http")
fake_nmap() {
  cat >"$STUBS/nmap" <<'NMAP'
#!/usr/bin/env bash
echo "nmap $*" >>"$(dirname "$0")/calls.log"
b=; prev=; for a; do [ "$prev" = -oA ] && b=$a; prev=$a; done
ip=${!#}
ports=; for p in ${FAKE_PORTS:-}; do IFS=/ read -r n pr s <<<"$p"; ports+="${ports:+, }$n/open/$pr//$s///"; done
[ -n "$b" ] || exit 0
printf '# Nmap fake\nHost: %s ()\tStatus: Up\n' "$ip" >"$b.gnmap"
[ -n "$ports" ] && printf 'Host: %s ()\tPorts: %s\n' "$ip" "$ports" >>"$b.gnmap"
echo fake >"$b.nmap"; echo '<x/>' >"$b.xml"
NMAP
  chmod +x "$STUBS/nmap"
}
