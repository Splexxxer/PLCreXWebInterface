#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/PLCreX"
RUNTIME_TOOLS_DIR="$REPO_ROOT/vendor/runtime-tools"
REPO_URL="https://github.com/marwern/PLCreX"
VENV_DIR="${PLCREX_VENV:-$REPO_ROOT/.venv-plcrex}"

is_windows_shell() {
  [[ "${OS:-}" == "Windows_NT" || "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${OSTYPE:-}" == win32 ]]
}

detect_windows_python39() {
  if [[ -n "${LOCALAPPDATA:-}" ]]; then
    local candidate="$LOCALAPPDATA/Programs/Python/Python39/python.exe"
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi
  return 1
}

split_command() {
  local command_string="$1"
  local -n out_array=$2
  read -r -a out_array <<< "$command_string"
}

require_python39_for_windows() {
  local -n python_cmd=$1
  local version
  version="$("${python_cmd[@]}" - <<'PY' | tr -d '\r\n'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PY
)"

  if is_windows_shell; then
    if [[ "$version" != "3.9" ]]; then
      echo "PLCreX on Windows requires Python 3.9 for its compiled modules."
      echo "Selected interpreter: ${python_cmd[*]}"
      echo "Detected version: $version"
      echo "Set PYTHON_BOOTSTRAP to a Python 3.9 interpreter and run just pull-plcrex again."
      exit 1
    fi
  fi
}

if [[ -n "${PYTHON:-}" ]]; then
  PYTHON_BIN="$PYTHON"
else
  if [[ -n "${PYTHON_BOOTSTRAP:-}" ]]; then
    BOOTSTRAP_PYTHON="$PYTHON_BOOTSTRAP"
  elif is_windows_shell; then
    if ! BOOTSTRAP_PYTHON="$(detect_windows_python39)"; then
      BOOTSTRAP_PYTHON="python"
    fi
  else
    BOOTSTRAP_PYTHON="python3"
  fi
  split_command "$BOOTSTRAP_PYTHON" BOOTSTRAP_CMD
  if [[ -d "$VENV_DIR" ]]; then
    echo "Removing existing PLCreX virtualenv at $VENV_DIR"
    rm -rf "$VENV_DIR"
  fi
  if ! command -v "${BOOTSTRAP_CMD[0]}" >/dev/null 2>&1; then
    echo "Bootstrap interpreter '$BOOTSTRAP_PYTHON' not found. Set PYTHON_BOOTSTRAP=/path/to/python or pre-create $VENV_DIR."
    exit 1
  fi
  require_python39_for_windows BOOTSTRAP_CMD
  echo "Creating PLCreX virtualenv at $VENV_DIR"
  "${BOOTSTRAP_CMD[@]}" -m venv "$VENV_DIR"
  if [[ -x "$VENV_DIR/bin/python" ]]; then
    PYTHON_BIN="$VENV_DIR/bin/python"
  elif [[ -x "$VENV_DIR/Scripts/python.exe" ]]; then
    PYTHON_BIN="$VENV_DIR/Scripts/python.exe"
  elif [[ -x "$VENV_DIR/Scripts/python" ]]; then
    PYTHON_BIN="$VENV_DIR/Scripts/python"
  else
    echo "Could not locate a Python interpreter inside $VENV_DIR after creating the PLCreX virtualenv."
    exit 1
  fi
fi

mkdir -p "$REPO_ROOT/vendor"
mkdir -p "$RUNTIME_TOOLS_DIR"

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

PYTHON_BIN_CMD=("$PYTHON_BIN")
require_python39_for_windows PYTHON_BIN_CMD

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
