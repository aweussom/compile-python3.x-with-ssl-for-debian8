#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}"

# Allow overriding the builder image/tag to match build.sh defaults.
image_name="${IMAGE_NAME:-pyinstaller-example}"
tag="${TAG:-latest}"

echo "[+] Building hello_world binary..."
./build.sh --entry hello_world.py

echo "[+] Verifying binary output..."
output="$(./dist/hello_world)"
echo "${output}"
if ! grep -q "hello, world" <<<"${output}"; then
  echo "[!] Unexpected output from hello_world binary" >&2
  exit 1
fi

echo "[+] Checking SSL inside builder image..."
docker run --rm "${image_name}:${tag}" python3 - <<'PY'
import ssl
import sys
print(sys.version.replace("\n", " "))
print(ssl.OPENSSL_VERSION)
PY

echo "[✓] Smoke test passed"
