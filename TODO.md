# Next steps

- [ ] Add `tag-release.sh` that reads git metadata (from `git_info.py` or `git describe`) and creates/pushes an annotated tag automatically.
- [ ] Experiment with PyInstaller `--version-file` to embed richer metadata (version, build source, timestamp) into the binary resources.
- [ ] Decide whether `tag-release.sh` should write a lightweight `git_info.txt` for human consumption alongside the binary or reuse `git_info.py`.
- [ ] Add a minimal GitHub Actions workflow to run `./smoke-test.sh` on push and optionally publish artifacts for tagged builds.
