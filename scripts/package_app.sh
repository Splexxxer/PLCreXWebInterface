#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"
BACKEND_DIR="$REPO_ROOT/backend"
VENDOR_DIR="$REPO_ROOT/vendor/PLCreX"
STAGING_DIR="$REPO_ROOT/.build/package"
NPM_BIN="${NPM_BIN:-npm}"

mkdir -p "$STAGING_DIR"
rm -rf "$STAGING_DIR"/*

echo "[1/4] Pulling PLCreX"
"$REPO_ROOT/scripts/pull_plcrex.sh"

echo "[2/4] Building frontend"
(cd "$FRONTEND_DIR" && "$NPM_BIN" install && "$NPM_BIN" run build)

echo "[3/4] Collecting backend and frontend artifacts"
mkdir -p "$STAGING_DIR/frontend" "$STAGING_DIR/backend"
cp -R "$FRONTEND_DIR"/dist "$STAGING_DIR/frontend/"
cp -R "$BACKEND_DIR" "$STAGING_DIR/backend/source"
if [[ -d "$VENDOR_DIR/.git" ]]; then
  cp -R "$VENDOR_DIR" "$STAGING_DIR/vendor"
fi

echo "[4/4] Generating SBOM placeholder"
if command -v syft >/dev/null 2>&1; then
  syft dir:"$STAGING_DIR" -o json > "$STAGING_DIR/sbom.json"
else
  echo "Syft not detected; skipping SBOM generation. Install Syft and rerun to capture the manifest."
fi

echo "Packaging staging directory ready at $STAGING_DIR"
echo "Add Docker image assembly steps here once runtime integration is ready."
