#!/usr/bin/env bash
# AutoBSPWN test suite: ./tests/run.sh [file.bats ...]   (vendored bats-core; default: all)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
if [ $# -eq 0 ]; then set -- "$here"; fi
exec "$here/vendor/bats-core/bin/bats" "$@"
