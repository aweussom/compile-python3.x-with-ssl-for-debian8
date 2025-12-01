#!/usr/bin/env bash
set -euo pipefail

# save_git_info.sh — generate git_info.py with version metadata
# Safe to run outside a Git repo; falls back to placeholder values.

ver="0.0.0-dev"
branch="unknown"
commit="unknown"

if command -v git >/dev/null 2>&1; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    ver=$(git describe --tags --always --dirty 2>/dev/null || echo "${ver}")
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "${branch}")
    commit=$(git rev-parse --short HEAD 2>/dev/null || echo "${commit}")
  fi
fi

cat > git_info.py <<EOF
__version__ = "${ver}"
__branch__  = "${branch}"
__commit__  = "${commit}"
EOF

exit 0
