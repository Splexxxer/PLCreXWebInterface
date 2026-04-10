#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/PLCreX"
REPO_URL="https://github.com/marwern/PLCreX"

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

if [[ ! -d "$VENDOR_DIR/.git" ]]; then
  echo "Cloning PLCreX into $VENDOR_DIR"
  git clone "$REPO_URL" "$VENDOR_DIR"
else
  echo "Updating existing PLCreX checkout"
  git -C "$VENDOR_DIR" remote set-url origin "$REPO_URL"
  git -C "$VENDOR_DIR" fetch origin --prune
fi

pushd "$VENDOR_DIR" >/dev/null
  git checkout "$DEFAULT_BRANCH"
  git reset --hard "origin/$DEFAULT_BRANCH"
popd >/dev/null

echo "PLCreX ready in $VENDOR_DIR"
