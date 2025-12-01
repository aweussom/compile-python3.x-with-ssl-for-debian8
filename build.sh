#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image_name="${IMAGE_NAME:-pyinstaller-example}"
tag="${TAG:-latest}"
entry="${ENTRYPOINT:-app.py}"
spec_file="${SPEC_FILE:-}"
requirements_file="${REQUIREMENTS_FILE:-requirements.txt}"
stamp="${STAMP:-$(date -u +%Y%m%d-%H%M)}" # UTC
dist_dir="${script_dir}/dist"

usage() {
  cat <<EOF
Usage: $0 [options]
  --entry FILE         Python entrypoint to compile (default: app.py)
  --spec FILE          Optional PyInstaller spec file (skips --onefile)
  --requirements FILE  Requirements file to install before building (default: requirements.txt)
  --image NAME         Docker image name (default: pyinstaller-example)
  --tag TAG            Docker image tag (default: latest)
  -h, --help           Show this help
Environment overrides: ENTRYPOINT, SPEC_FILE, REQUIREMENTS_FILE, IMAGE_NAME, TAG, STAMP
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --entry) entry="${2:-$entry}"; shift ;;
    --spec) spec_file="${2:-$spec_file}"; shift ;;
    --requirements) requirements_file="${2:-$requirements_file}"; shift ;;
    --image) image_name="${2:-$image_name}"; shift ;;
    --tag) tag="${2:-$tag}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[!] Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

mkdir -p "${dist_dir}"

echo "[+] Building Docker image ${image_name}:${tag}..."
docker build -t "${image_name}:${tag}" "${script_dir}"
docker tag "${image_name}:${tag}" "${image_name}:${tag}-${stamp}"
echo "[i] Additional tag: ${image_name}:${tag}-${stamp}"

echo "[+] Running PyInstaller build..."
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e ENTRYPOINT="${entry}" \
  -e SPEC_FILE="${spec_file}" \
  -e REQUIREMENTS_FILE="${requirements_file}" \
  -v "${script_dir}:/src:ro" \
  -v "${dist_dir}:/out" \
  "${image_name}:${tag}" \
  bash -lc 'set -euo pipefail
    cp -r /src /tmp/src
    cd /tmp/src

    if [[ -n "${REQUIREMENTS_FILE:-}" && -f "${REQUIREMENTS_FILE}" ]]; then
      echo "[i] Installing requirements from ${REQUIREMENTS_FILE}"
      python -m pip install --no-cache-dir -r "${REQUIREMENTS_FILE}"
    else
      echo "[i] No requirements file found; skipping dependency install"
    fi

    EXTRA_LD="$(python - <<'"'"'PY'"'"'
import os
import site

libs = []
for base in site.getsitepackages():
    for entry in os.listdir(base):
        if entry.endswith(".libs"):
            path = os.path.join(base, entry)
            if os.path.isdir(path):
                libs.append(path)
print(":".join(libs))
PY
)"
    if [[ -n "${EXTRA_LD}" ]]; then
      export LD_LIBRARY_PATH="${EXTRA_LD}:${LD_LIBRARY_PATH:-}"
      echo "[i] Added to LD_LIBRARY_PATH: ${EXTRA_LD}"
    fi

    if [[ -n "${SPEC_FILE:-}" ]]; then
      if [[ ! -f "${SPEC_FILE}" ]]; then
        echo "[!] Spec file ${SPEC_FILE} not found" >&2
        exit 1
      fi
      echo "[i] Using spec file ${SPEC_FILE}"
      python -m PyInstaller --clean "${SPEC_FILE}" --distpath /tmp/dist --workpath /tmp/build --specpath /tmp
    else
      echo "[i] Building onefile binary from ${ENTRYPOINT}"
      python -m PyInstaller --clean --onefile "${ENTRYPOINT}" --distpath /tmp/dist --workpath /tmp/build --specpath /tmp
    fi

    mkdir -p /out
    cp -r /tmp/dist/* /out/
    echo "[+] Build complete. Files in /out:"
    ls -lh /out'

echo "[+] Done. Artifacts are in ${dist_dir}"
echo "[i] You can re-run the container directly with:"
cat <<EOF
  docker run --rm \\
    -u "\$(id -u):\$(id -g)" \\
    -e HOME=/tmp \\
    -e ENTRYPOINT="${entry}" \\
    -e SPEC_FILE="${spec_file}" \\
    -e REQUIREMENTS_FILE="${requirements_file}" \\
    -v "${script_dir}:/src:ro" \\
    -v "${dist_dir}:/out" \\
    "${image_name}:${tag}-${stamp}" \\
    bash -lc '...'
EOF
