"""Helpers for inspecting PLCreX CLI metadata."""

from __future__ import annotations

import os
import re
import shlex
import subprocess
import sys
import logging
from functools import lru_cache
from pathlib import Path
from typing import Iterable

from fastapi import HTTPException, status

from ..models.plcrex import PlcrexCommand

HELP_COMMAND_ENV = "PLCREX_HELP_COMMAND"
VENDOR_ENV = "PLCREX_VENDOR_PATH"
DEFAULT_HELP_COMMAND = [sys.executable, "-m", "plcrex", "--help"]
logger = logging.getLogger(__name__)

COMMAND_SECTION_HEADER = "Commands"
TABLE_ROW_PREFIX = "│"
TABLE_SECTION_EDGE = "╰"
ASCII_COMMAND_PREFIX = "  "


class PlcrexCommandError(RuntimeError):
    """Raised when PLCreX command discovery fails."""


def get_vendor_path() -> Path | None:
    """Return the vendor checkout path if it exists."""

    candidate = os.getenv(VENDOR_ENV)
    if candidate:
        candidate_path = Path(candidate)
        if candidate_path.exists():
            return candidate_path

    default = Path(__file__).resolve().parents[2] / "vendor" / "PLCreX"
    return default if default.exists() else None


def build_env() -> dict[str, str]:
    """Build an environment ensuring PLCreX is on PYTHONPATH when installed from vendor."""

    env = os.environ.copy()
    # PLCreX help uses Typer/Rich. On Windows subprocess pipes can default to cp1252,
    # which crashes on unicode glyphs like the arrow in "*.xml → *.sctx".
    env.setdefault("PYTHONIOENCODING", "utf-8")
    env.setdefault("PYTHONUTF8", "1")
    vendor_path = get_vendor_path()
    if vendor_path:
        python_path = env.get("PYTHONPATH")
        vendor_str = str(vendor_path)
        env["PYTHONPATH"] = vendor_str if not python_path else f"{vendor_str}{os.pathsep}{python_path}"
    return env


def build_help_command() -> list[str]:
    """Determine the command used to query PLCreX help output."""

    override = os.getenv(HELP_COMMAND_ENV)
    if override:
        return shlex.split(override, posix=os.name != "nt")
    return DEFAULT_HELP_COMMAND


def read_plcrex_help() -> str:
    """Execute the PLCreX help command and return stdout."""

    command = build_help_command()
    logger.info("Running PLCreX help command: %s", command)
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            check=True,
            env=build_env(),
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        logger.exception("PLCreX help command executable not found")
        raise PlcrexCommandError(f"Unable to execute PLCreX help command: {exc}") from exc
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip() if exc.stderr else ""
        message = stderr or "PLCreX help command failed"
        logger.error(
            "PLCreX help command failed with return code %s. stderr=%s stdout=%s",
            exc.returncode,
            stderr,
            exc.stdout.strip() if exc.stdout else "",
        )
        raise PlcrexCommandError(message) from exc

    logger.info("PLCreX help command completed successfully")
    return completed.stdout or ""


def parse_command_table(lines: Iterable[str]) -> list[PlcrexCommand]:
    """Parse the unicode table rendered by Typer/Rich."""

    commands: list[PlcrexCommand] = []
    capture = False
    for raw_line in lines:
        line = raw_line.rstrip("\n")
        if not capture and COMMAND_SECTION_HEADER in line:
            capture = True
            continue
        if not capture:
            continue
        if line.startswith(TABLE_SECTION_EDGE):
            break
        if not line.startswith(TABLE_ROW_PREFIX):
            continue

        content = line.strip("│").strip()
        if not content or content.startswith("─"):
            continue

        parts = [segment.strip() for segment in re.split(r"\s{2,}", content) if segment.strip()]
        if not parts:
            continue
        name = parts[0]
        summary = parts[1] if len(parts) > 1 else ""
        io = parts[2] if len(parts) > 2 else None
        commands.append(PlcrexCommand(name=name, summary=summary, io=io))

    return commands


def parse_ascii_list(lines: Iterable[str]) -> list[PlcrexCommand]:
    """Fallback parser when unicode tables are unavailable."""

    commands: list[PlcrexCommand] = []
    capture = False
    for raw_line in lines:
        line = raw_line.rstrip("\n")
        if not capture and line.strip().startswith("Commands"):
            capture = True
            continue
        if not capture:
            continue
        if not line.startswith(ASCII_COMMAND_PREFIX):
            if commands and not line.strip():
                break
            continue
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(" ", 1)
        name = parts[0]
        summary = parts[1].strip() if len(parts) > 1 else ""
        commands.append(PlcrexCommand(name=name, summary=summary))
    return commands


def parse_plcrex_help(output: str) -> list[PlcrexCommand]:
    """Convert PLCreX help output into structured commands."""

    lines = output.splitlines()
    commands = parse_command_table(lines)
    if commands:
        return commands
    return parse_ascii_list(lines)


@lru_cache(maxsize=1)
def cached_plcrex_commands() -> tuple[PlcrexCommand, ...]:
    """Cache the parsed command list to avoid repeated subprocess invocations."""

    output = read_plcrex_help()
    commands = parse_plcrex_help(output)
    if not commands:
        raise PlcrexCommandError("Unable to parse PLCreX help output.")
    return tuple(commands)


def get_plcrex_commands(force_refresh: bool = False) -> list[PlcrexCommand]:
    """Return PLCreX commands, optionally forcing a refresh."""

    if force_refresh:
        cached_plcrex_commands.cache_clear()
    try:
        return list(cached_plcrex_commands())
    except PlcrexCommandError as exc:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc
