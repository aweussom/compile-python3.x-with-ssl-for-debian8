#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./package-debs.sh [--stamp YYYYMMDD-HHMM] [--binary PATH] [--name NAME] [--description TEXT] [--arch ARCH]

Packages a PyInstaller-built binary into a simple .deb.
Defaults assume you built the onefile binary to dist/app.
Outputs to release/<STAMP>/<NAME>_<STAMP>_<ARCH>.deb

Examples:
  ./package-debs.sh
  ./package-debs.sh --binary dist/hello_world --name hello-world
  ./package-debs.sh --stamp 20251231-1200 --arch amd64
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="${STAMP:-$(date -u +%Y%m%d-%H%M)}"
binary="${BINARY_PATH:-${repo_root}/dist/app}"
name="${PKG_NAME:-demo-app}"
description="${PKG_DESCRIPTION:-Demo app built with PyInstaller}"
arch="${ARCH:-$(dpkg --print-architecture 2>/dev/null || echo amd64)}"
release_dir="${repo_root}/release/${stamp}"
pkg_root="${repo_root}/pkg-build"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stamp) stamp="${2:-$stamp}"; shift ;;
    --binary) binary="${2:-$binary}"; shift ;;
    --name) name="${2:-$name}"; shift ;;
    --description) description="${2:-$description}"; shift ;;
    --arch) arch="${2:-$arch}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[!] Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

command -v dpkg-deb >/dev/null 2>&1 || { echo "[!] dpkg-deb is required" >&2; exit 1; }

mkdir -p "$release_dir"
mkdir -p "$pkg_root"

require_file() {
  local file="$1"
  local hint="${2:-}"
  if [[ ! -f "$file" ]]; then
    echo "[!] Missing required file: $file" >&2
    if [[ -n "$hint" ]]; then
      echo "[!] $hint" >&2
    fi
    exit 1
  fi
}

write_control() {
  local path="$1"
  cat > "$path" <<EOF
Package: ${name}
Version: ${stamp}
Section: misc
Priority: optional
Architecture: ${arch}
Maintainer: Example Maintainer <maintainer@example.com>
Depends: libc6 (>= 2.19), libstdc++6 (>= 4.9)
Description: ${description}
 Built from PyInstaller onefile binary.
EOF
}

build_deb() {
  local stage="${pkg_root}/build"
  local deb_name="${name}_${stamp}_${arch}.deb"

  require_file "$binary" "Run './build.sh' first to produce the binary at ${binary}"

  rm -rf "$stage"
  mkdir -p \
    "$stage/DEBIAN" \
    "$stage/usr/local/bin"

  install -m 0755 "$binary" "$stage/usr/local/bin/${name}"

  write_control "$stage/DEBIAN/control"

  dpkg-deb --build "$stage" "$release_dir/${deb_name}"
  echo "[+] Built $release_dir/${deb_name}"
}

build_deb

echo "[i] Done. Package is in $release_dir"
echo ""
echo "Next steps:"
echo "  1. Copy .deb package to target system"
echo "  2. Install: sudo dpkg -i ${name}_${stamp}_${arch}.deb"
echo "  3. Run: ${name}"
