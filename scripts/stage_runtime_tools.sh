#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_TOOLS_DIR="$REPO_ROOT/vendor/runtime-tools"

is_windows_shell() {
  [[ "${OS:-}" == "Windows_NT" || "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${OSTYPE:-}" == win32 ]]
}

is_placeholder_path() {
  local value="$1"
  [[ "$value" == *'C:\path\to\'* || "$value" == *'/path/to/'* || "$value" == *'example'* ]]
}

detect_runtime_tool_path() {
  local tool_name="$1"
  local candidate

  if ! is_windows_shell; then
    return 1
  fi

  case "$tool_name" in
    nusmv)
      for candidate in \
        "$REPO_ROOT/vendor/runtime-tools/nusmv/NuSMV.exe" \
        "$REPO_ROOT/vendor/runtime-tools/nusmv/bin/NuSMV.exe" \
        "$REPO_ROOT/vendor/runtime-tools/NuSMV-2.7.1-win64/bin/NuSMV.exe" \
        "$LOCALAPPDATA/Programs/NuSMV/bin/NuSMV.exe" \
        "$LOCALAPPDATA/Programs/NuSMV/NuSMV.exe" \
        "/c/Program Files/NuSMV/bin/NuSMV.exe" \
        "/c/Program Files/NuSMV/NuSMV.exe" \
        "/c/Program Files (x86)/NuSMV/bin/NuSMV.exe" \
        "/c/Program Files (x86)/NuSMV/NuSMV.exe"
      do
        if [[ -f "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      ;;
    iec-checker)
      for candidate in \
        "$REPO_ROOT/vendor/runtime-tools/iec-checker/iec_checker_Windows_x86_64_v0.4.exe" \
        "$REPO_ROOT/vendor/runtime-tools/iec_checker_Windows_x86_64.exe" \
        "$LOCALAPPDATA/Programs/iec-checker/iec_checker_Windows_x86_64_v0.4.exe" \
        "$LOCALAPPDATA/Programs/iec-checker/iec_checker.exe" \
        "/c/Program Files/iec-checker/iec_checker_Windows_x86_64_v0.4.exe" \
        "/c/Program Files/iec-checker/iec_checker.exe" \
        "/c/Program Files (x86)/iec-checker/iec_checker_Windows_x86_64_v0.4.exe" \
        "/c/Program Files (x86)/iec-checker/iec_checker.exe"
      do
        if [[ -f "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      ;;
    kicodia)
      for candidate in \
        "$REPO_ROOT/vendor/runtime-tools/kicodia/kicodia-win.bat" \
        "$LOCALAPPDATA/Programs/Kicodia/kicodia-win.bat" \
        "/c/Program Files/Kicodia/kicodia-win.bat" \
        "/c/Program Files (x86)/Kicodia/kicodia-win.bat"
      do
        if [[ -f "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      ;;
  esac

  return 1
}

stage_runtime_tool() {
  local source_path="$1"
  local target_dir="$2"
  local target_name="$3"
  local tool_name="$4"

  if [[ -n "$source_path" ]] && is_placeholder_path "$source_path"; then
    echo "Ignoring placeholder runtime tool path for $tool_name: $source_path"
    source_path=""
  fi

  if [[ -z "$source_path" ]]; then
    source_path="$(detect_runtime_tool_path "$tool_name" || true)"
  fi

  if [[ -z "$source_path" ]]; then
    echo "Runtime tool not found for $tool_name. Continuing without staging it."
    return 0
  fi

  if [[ ! -f "$source_path" ]]; then
    echo "Configured runtime tool not found for $tool_name: $source_path"
    echo "Continuing without staging it."
    return 0
  fi

  mkdir -p "$target_dir"
  cp "$source_path" "$target_dir/$target_name"
  echo "Staged backend runtime tool: $target_dir/$target_name"
}

print_tool_status() {
  local tool_name="$1"
  local display_name="$2"
  local resolved
  resolved="$(detect_runtime_tool_path "$tool_name" || true)"
  if [[ -n "$resolved" ]]; then
    echo "$display_name: FOUND -> $resolved"
  else
    echo "$display_name: missing"
  fi
}

mkdir -p "$RUNTIME_TOOLS_DIR"

case "${1:-stage}" in
  stage)
    stage_runtime_tool "${PLCREX_NUSMV_SOURCE:-}" "$RUNTIME_TOOLS_DIR/nusmv" "NuSMV.exe" "nusmv"
    stage_runtime_tool "${PLCREX_IEC_CHECKER_SOURCE:-}" "$RUNTIME_TOOLS_DIR/iec-checker" "iec_checker_Windows_x86_64_v0.4.exe" "iec-checker"
    stage_runtime_tool "${PLCREX_KICODIA_SOURCE:-}" "$RUNTIME_TOOLS_DIR/kicodia" "kicodia-win.bat" "kicodia"
    ;;
  status)
    print_tool_status "nusmv" "NuSMV"
    print_tool_status "iec-checker" "IEC Checker"
    print_tool_status "kicodia" "Kicodia"
    ;;
  *)
    echo "Usage: $0 [stage|status]"
    exit 1
    ;;
esac
