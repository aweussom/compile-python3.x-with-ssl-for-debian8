# Python + Flask: Shipping a Compiled Binary (PyInstaller)

Practical checklist for turning a Flask app into a single-file executable with PyInstaller, including config handling so missing `.ini` files do not break startup.

## Pre-flight considerations
- **Entry point clarity:** Keep a single `app = Flask(...)` entry file. Avoid global side effects on import (load configs lazily).
- **Static/templates:** Ensure `templates/` and `static/` are bundled via `--add-data` so Jinja and assets resolve when frozen.
- **Data files:** List required data (e.g., `.xlsx`, `.yml`) and include them with `--add-data src:dest`.
- **Config strategy:** Support both environment variables and an `.ini` file. Allow override via `<APPNAME>_CONFIG`-style env (choose a clear name).
- **Runtime paths:** Use a helper like `resource_path` to resolve files when running from source or from a PyInstaller `_MEIPASS` bundle.

## Build steps (one-file PyInstaller inside Docker)
1) Build a minimal image with Python + PyInstaller (or use an existing one): Use main repo here as inspiration/source.
2) Copy source into the container; install `requirements.txt`.
3) Run PyInstaller with `--onefile` and `--add-data` flags for templates, static assets, configs, and data files.
4) Copy artifacts out of the container to `dist/`.

Example ```bash build.sh``` is in this repo.

Example command skeleton:
```bash
python3 -m PyInstaller --clean --onefile app.py \
  --name myapp \
  --add-data "templates:templates" \
  --add-data "static:static" \
  --add-data "config.ini:config.ini" \
  --add-data "config_template.ini:config_template.ini"
```

## Config fail-safes (.ini + template)
- **Lookup order:** 1) explicit env override (`APP_CONFIG=/path/config.ini`), 2) `./config.ini` in current working dir, 3) bundled `config.ini`, 4) bundled `config_template.ini`.
- **Template usage:** Ship a `config_template.ini` with sane defaults; bundle it so the binary always finds a readable file even when a real config is missing.
- **Environment precedence:** At runtime, let env variables override `.ini` values to ease container/ops usage.
- **Error handling:** If all lookups fail, raise a clear error or fall back to the template to keep the binary starting.

## Path resolution pattern
Use a helper to resolve paths both in source and frozen mode:
```python
import os, sys

def resource_path(rel):
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, rel)
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), rel)
```

## Testing the frozen app
- Run the binary and hit `/` and `/api/...` endpoints to ensure templates/static load correctly.
- Confirm config resolution: remove local `config.ini` and verify the binary still starts via the bundled template.
- Verify data files (Excel/CSV/YAML) are present in the bundle and load without file-not-found errors.
- Check logs for warnings about missing configs or endpoints.
