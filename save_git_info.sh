#!/usr/bin/env bash
set -euo pipefail

# save_git_info.sh — generate git_info.py with version metadata
# Safe to run outside a Git repo; falls back to placeholder values.

ver="0.0.0-dev"
branch="unknown"
commit="unknown"
build_source="${BUILD_SOURCE:-}"
version_source="${VERSION_SOURCE:-}"

if command -v git >/dev/null 2>&1; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    ver=$(git describe --tags --always --dirty 2>/dev/null || echo "${ver}")
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "${branch}")
    commit=$(git rev-parse --short HEAD 2>/dev/null || echo "${commit}")
    if [[ -z "${version_source}" ]]; then
      if git describe --tags --exact-match >/dev/null 2>&1; then
        version_source="tag"
      else
        version_source="branch"
      fi
    fi
  fi
fi

if [[ -z "${build_source}" ]]; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    build_source="github"
  else
    build_source="local"
  fi
fi

if [[ -z "${version_source}" ]]; then
  version_source="timestamp"
fi

cat > git_info.py <<EOF
__version__ = "${ver}"
__branch__  = "${branch}"
__commit__  = "${commit}"
__build_source__ = "${build_source}"
__version_source__ = "${version_source}"
EOF

exit 0
