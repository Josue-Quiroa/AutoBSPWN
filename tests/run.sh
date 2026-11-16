#!/usr/bin/env bash
# AutoBSPWN test suite: ./tests/run.sh [bats-options] [file.bats ...]   (vendored bats-core; default: all)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
has_target=0
for a in "$@"; do case "$a" in -*) ;; *) has_target=1 ;; esac; done
if [ "$has_target" -eq 0 ]; then set -- "$@" "$here"; fi
exec "$here/vendor/bats-core/bin/bats" "$@"
