#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/PLCreX"
REPO_URL="https://github.com/marwern/PLCreX"
VENV_DIR="${PLCREX_VENV:-$REPO_ROOT/.venv-plcrex}"

if [[ -n "${PYTHON:-}" ]]; then
  PYTHON_BIN="$PYTHON"
else
  BOOTSTRAP_PYTHON="${PYTHON_BOOTSTRAP:-python3}"
  if [[ -d "$VENV_DIR" ]]; then
    echo "Removing existing PLCreX virtualenv at $VENV_DIR"
    rm -rf "$VENV_DIR"
  fi
  if ! command -v "$BOOTSTRAP_PYTHON" >/dev/null 2>&1; then
    echo "Bootstrap interpreter '$BOOTSTRAP_PYTHON' not found. Set PYTHON_BOOTSTRAP=/path/to/python or pre-create $VENV_DIR."
    exit 1
  fi
  echo "Creating PLCreX virtualenv at $VENV_DIR"
  "$BOOTSTRAP_PYTHON" -m venv "$VENV_DIR"
  PYTHON_BIN="$VENV_DIR/bin/python"
fi

mkdir -p "$REPO_ROOT/vendor"

resolve_default_branch() {
  local branch
  branch="$(git ls-remote --symref "$REPO_URL" HEAD 2>/dev/null | awk '/^ref:/ {print $2}' | sed 's@refs/heads/@@')"
  if [[ -z "$branch" ]]; then
    echo "main"
  else
    echo "$branch"
  fi
}

DEFAULT_BRANCH="$(resolve_default_branch)"

echo "Using upstream branch: $DEFAULT_BRANCH"

if [[ -d "$VENDOR_DIR" ]]; then
  echo "Removing existing PLCreX checkout at $VENDOR_DIR"
  rm -rf "$VENDOR_DIR"
fi

echo "Cloning PLCreX into $VENDOR_DIR"
git clone --branch "$DEFAULT_BRANCH" "$REPO_URL" "$VENDOR_DIR"

pushd "$VENDOR_DIR" >/dev/null
  git checkout "$DEFAULT_BRANCH"
popd >/dev/null

echo "PLCreX ready in $VENDOR_DIR"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python interpreter '$PYTHON_BIN' not found. Set PYTHON=/path/to/python when invoking this script."
  exit 1
fi

USER_SITE=$("$PYTHON_BIN" - <<'PY' | tr -d '\n'
import site
print(site.getusersitepackages())
PY
)

if [[ -z "$USER_SITE" ]]; then
  PYTHONPATH_EXTRA="$VENDOR_DIR"
else
  PYTHONPATH_EXTRA="$USER_SITE:$VENDOR_DIR"
fi

echo "Installing PLCreX (editable) via $PYTHON_BIN"
"$PYTHON_BIN" -m pip install --upgrade pip wheel
# setuptools>=80 removed pkg_resources which PLCreX's deps still import
# during build. Pin below that threshold so pkg_resources stays available.
"$PYTHON_BIN" -m pip install --upgrade --force-reinstall "setuptools>=65,<80"

PYEDA_PATCH="$REPO_ROOT/vendor/patched-packages/pyeda-0.29.0-patched.tar.gz"
if [[ -f "$PYEDA_PATCH" ]]; then
  echo "Installing patched pyeda from $PYEDA_PATCH"
  # PyEDA 0.29.0 bundles Espresso C sources that fail to build on macOS/clang
  # because its qsort comparator has the wrong prototype; ship a patched sdist.
  PIP_NO_BUILD_ISOLATION=1 PYTHONPATH="$PYTHONPATH_EXTRA" \
    "$PYTHON_BIN" -m pip install --no-build-isolation --no-deps --force-reinstall "$PYEDA_PATCH"
fi

PIP_NO_BUILD_ISOLATION=1 PYTHONPATH="$PYTHONPATH_EXTRA" "$PYTHON_BIN" -m pip install --no-build-isolation -r "$VENDOR_DIR/requirements.txt"
PIP_NO_BUILD_ISOLATION=1 PYTHONPATH="$PYTHONPATH_EXTRA" "$PYTHON_BIN" -m pip install --no-build-isolation -e "$VENDOR_DIR" --no-deps
