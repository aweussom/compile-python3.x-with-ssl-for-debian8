Minimal example showing how to compile a Python script into a standalone binary with PyInstaller inside Docker. This is a cleaned-up, reusable sample you can drop into any project. It uses Debian Jessie as the base and builds OpenSSL and Python from source to avoid the broken SSL in the stock distro.

## What's inside
- `Dockerfile` – reproducible builder image with Python and PyInstaller.
- `build.sh` – helper that builds the image, runs PyInstaller in an isolated container, and writes binaries to `dist/`.
- `app.py` – tiny sample entrypoint; replace with your own application.
- `hello_world.py` – even smaller smoke-test script to prove the toolchain works.
- `requirements.txt` – where you pin dependencies for the build.
- `package-debs.sh` – optional step to wrap the built binary into a .deb with a date-based version.
- `save_git_info.sh` – optional helper to generate `git_info.py` from your current Git state.

## Quick start
```bash
cd /tmp/compile-python
chmod +x build.sh
./build.sh
# dist/app now contains a self-contained binary
# or build the bare-minimum sample:
# ./build.sh --entry hello_world.py
```

Open the binary to verify it runs:
```bash
./dist/app --help
./dist/hello_world
```

## Options
- `--entry FILE` to set the Python entrypoint (default: `app.py`).
- `--spec FILE` if you already have a PyInstaller spec file.
- `--image NAME` to change the Docker image name (default: `pyinstaller-example`).
- `--tag TAG` to change the image tag (default: `latest`).
- `--dist DIR` to change the host output directory (default: `./dist` next to the script).
- `--dockerfile FILE` to point at a different Dockerfile (default: `./Dockerfile`).
- `--requirements FILE` to install dependencies before building (default: `requirements.txt` when present).

You can also set environment variables instead of flags: `ENTRYPOINT`, `SPEC_FILE`, `IMAGE_NAME`, `TAG`, `DIST_DIR`, `DOCKERFILE_PATH`, `REQUIREMENTS_FILE`, `STAMP`.

## Full flow (opinionated)
1) Write code: put your entry script in the repo (e.g., `app.py`).
2) Pin dependencies: update `requirements.txt` with exact versions.
3) (Optional) Embed git metadata: run `./save_git_info.sh` to generate `git_info.py` so your binary knows its Git describe/branch/commit.
4) Build the binary: `./build.sh --entry app.py` (or your entry). This pulls/builds the Docker image, compiles OpenSSL+Python, installs deps, and runs PyInstaller. The default version stamp is UTC `YYYYMMDD-HHMM`.
5) Package as .deb (optional): `./package-debs.sh --binary dist/app --name my-app` to get `release/<STAMP>/my-app_<STAMP>_<ARCH>.deb`.

## How it works
1) `Dockerfile` uses Debian Jessie for broad glibc compatibility, rebuilds OpenSSL 1.0.2u, then compiles Python 3.8.x against it to restore working SSL, and finally installs PyInstaller.
2) `build.sh` builds the image, mounts your source tree read-only, and copies it to a temporary workspace inside the container.
3) If a requirements file is present, dependencies are installed inside the container only.
4) PyInstaller runs with `--distpath /tmp/dist` and `--workpath /tmp/build` to keep host directories clean.
5) Shared-library wheels (e.g., `opencv_python`) often bundle `.libs/` folders; the script auto-detects these and adds them to `LD_LIBRARY_PATH` so PyInstaller can find the native artifacts.
6) Finished binaries are copied back to `dist/` on the host.

## Notes
- Docker is required. The build image downloads and compiles OpenSSL and Python, so expect a longer first build and network access.
- The Jessie base improves compatibility with older glibc targets; adjust the Dockerfile if you prefer a newer base.
- For multi-binary projects, run `./build.sh --entry other.py` (or provide multiple spec files) and collect the outputs in `dist/`.
- Adjust the Dockerfile if you need older glibc compatibility or specific build deps.

## Smoke test (optional)
Run a quick end-to-end check:
```bash
./smoke-test.sh
```
This rebuilds the image if needed, builds the `hello_world.py` binary, runs it to confirm output, and checks that SSL works inside the container (`import ssl` shows the OpenSSL version).

## Limitations and compatibility
- Base image is Debian Jessie to hit an old glibc target. If you only care about newer distros, swap the base image and bump Python/OpenSSL accordingly.
- Network is required the first time to download OpenSSL/Python sources.
- PyInstaller is pinned to 5.13.2; adjust if you need features from newer releases, but test compatibility with your target glibc.
- Native wheels with bundled `.libs` are supported via `LD_LIBRARY_PATH` auto-detection, but custom native dependencies may require extending the Dockerfile.

## Versioning philosophy
- Default versioning uses a build-date stamp: `STAMP` defaults to UTC `YYYYMMDD-HHMM` and is used for image tags, output naming, and .deb versions. For operations, a build timestamp is clearer than semantic versions (e.g., `1.0.1b`).
- If you want Git-derived versions, run `./save_git_info.sh` before building; this writes `git_info.py` with `__version__`, `__branch__`, `__commit__`, plus metadata for provenance: `__build_source__` (local | github) and `__version_source__` (timestamp | tag | branch | api). Defaults use the timestamp unless a tag is detected; environment overrides are `BUILD_SOURCE` and `VERSION_SOURCE`.

## License
A license file should be added before treating this as open source; choose MIT/BSD/Apache or similar to make reuse unambiguous.

## Why rebuild OpenSSL and Python here?
- Jessie’s packaged OpenSSL is EOL and its SSL stack is effectively broken for modern HTTPS endpoints. Rebuilding OpenSSL 1.0.2u (still compatible with old glibc) fixes TLS so dependency downloads and runtime HTTPS calls work.
- Python is compiled from source against that OpenSSL to ensure the interpreter’s ssl module is functional inside the container and in the produced binaries.
- Python 3.8.x is used as a middle ground: Python 3.7 is the oldest still reasonably usable, but 3.8 buys a few more stdlib and packaging fixes while staying compatible with older glibc targets. If you need a different version, change `PY_VER` in the Dockerfile.
