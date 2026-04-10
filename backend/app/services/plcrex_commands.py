"""Helpers for inspecting and executing PLCreX commands."""

from __future__ import annotations

import json
import logging
import os
import re
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Iterable
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status

from ..models.plcrex import PlcrexCommand, PlcrexOption, PlcrexRunOutput, PlcrexRunResponse

HELP_COMMAND_ENV = "PLCREX_HELP_COMMAND"
RUNTIME_TEMP_ENV = "PLCREX_RUNTIME_TEMP"
VENDOR_ENV = "PLCREX_VENDOR_PATH"
logger = logging.getLogger(__name__)

COMMAND_SECTION_HEADER = "Commands"
TABLE_ROW_PREFIXES = ("|", "│")
TABLE_SECTION_EDGES = ("+-", "╰")
ASCII_COMMAND_PREFIX = "  "


class PlcrexCommandError(RuntimeError):
    """Raised when PLCreX command discovery fails."""


class PlcrexRunError(RuntimeError):
    """Raised when PLCreX command execution fails."""


@dataclass(frozen=True)
class CommandOptionSpec:
    name: str
    flag: str
    label: str
    description: str
    default: bool = False


@dataclass(frozen=True)
class CommandSpec:
    accepts_upload: bool = True
    input_extensions: tuple[str, ...] = ()
    output_extensions: tuple[str, ...] = ()
    option_specs: tuple[CommandOptionSpec, ...] = ()
    unsupported_reason: str | None = None
    uses_stdout: bool = False
    runtime_tool: str | None = None


COMMAND_SPECS: dict[str, CommandSpec] = {
    "fbd-to-sctx": CommandSpec(
        input_extensions=(".xml",),
        output_extensions=(".sctx",),
        option_specs=(
            CommandOptionSpec("edge_opt", "--edge-opt", "Optimize edges", "Enable PLCreX edge optimization."),
            CommandOptionSpec("var_opt", "--var-opt", "Optimize variables", "Enable PLCreX variable optimization."),
            CommandOptionSpec("op_opt", "--op-opt", "Optimize operators", "Enable PLCreX operator optimization."),
        ),
        runtime_tool="nusmv",
    ),
    "fbd-to-st": CommandSpec(
        input_extensions=(".xml",),
        output_extensions=(".st",),
        option_specs=(
            CommandOptionSpec("bwd", "--bwd", "Backward translation", "Use PLCreX backward translation."),
            CommandOptionSpec("formal", "--formal", "Formal parameters", "Emit formal parameter lists."),
        ),
    ),
    "fbd-to-st-ext": CommandSpec(
        input_extensions=(".xml",),
        output_extensions=(".st",),
        option_specs=(
            CommandOptionSpec("edge_opt", "--edge-opt", "Optimize edges", "Enable PLCreX edge optimization."),
            CommandOptionSpec("var_opt", "--var-opt", "Optimize variables", "Enable PLCreX variable optimization."),
            CommandOptionSpec("op_opt", "--op-opt", "Optimize operators", "Enable PLCreX operator optimization."),
        ),
        runtime_tool="nusmv",
    ),
    "iec-check": CommandSpec(
        input_extensions=(".st",),
        output_extensions=(".log",),
        option_specs=(
            CommandOptionSpec("verbose", "--verbose", "Verbose log", "Return the full IEC checker log."),
            CommandOptionSpec("help_iec_checker", "--help_iec_checker", "Show checker help", "Pass through IEC checker help."),
        ),
        runtime_tool="iec_checker",
    ),
    "impact-analysis": CommandSpec(
        input_extensions=(".xml",),
        output_extensions=(".dot",),
    ),
    "st-parser": CommandSpec(
        input_extensions=(".st",),
        output_extensions=(".dot", ".txt"),
        option_specs=(
            CommandOptionSpec("txt", "--txt", "Text tree", "Generate the `.txt` parse tree.", default=True),
            CommandOptionSpec("dot", "--dot", "DOT tree", "Generate the `.dot` parse tree.", default=True),
            CommandOptionSpec("beckhoff", "--beckhoff", "Beckhoff grammar", "Use Beckhoff TwinCAT ST grammar."),
        ),
    ),
    "st-to-qrz": CommandSpec(
        input_extensions=(".st",),
        output_extensions=(".qrz",),
    ),
    "st-to-scl": CommandSpec(
        input_extensions=(".st",),
        output_extensions=(".scl",),
    ),
    "st-to-sctx": CommandSpec(
        input_extensions=(".st",),
        output_extensions=(".sctx",),
        runtime_tool="kicodia",
    ),
    "test-case-gen": CommandSpec(
        accepts_upload=False,
        unsupported_reason="This command needs a formula string instead of a file upload.",
        uses_stdout=True,
    ),
    "xml-validator": CommandSpec(
        input_extensions=(".xml",),
        uses_stdout=True,
        option_specs=(
            CommandOptionSpec("v201", "--v201", "Use v201 schema", "Validate against the tc6_xml_v201 schema."),
        ),
    ),
}

RUNTIME_TOOL_CONFIG: dict[str, dict[str, object]] = {
    "nusmv": {
        "label": "NuSMV runtime",
        "env": "PLCREX_NUSMV_PATH",
        "candidates": (
            "vendor/runtime-tools/nusmv/NuSMV.exe",
            "vendor/runtime-tools/nusmv/bin/NuSMV.exe",
            "vendor/runtime-tools/NuSMV-2.7.1-win64/bin/NuSMV.exe",
            "vendor/runtime-tools/NuSMV.exe",
        ),
    },
    "iec_checker": {
        "label": "IEC Checker runtime",
        "env": "PLCREX_IEC_CHECKER_PATH",
        "candidates": (
            "vendor/runtime-tools/iec-checker/iec_checker_Windows_x86_64_v0.4.exe",
            "vendor/runtime-tools/iec-checker/iec_checker.exe",
            "vendor/runtime-tools/iec_checker_Windows_x86_64.exe",
            "vendor/runtime-tools/iec_checker.exe",
        ),
    },
    "kicodia": {
        "label": "Kicodia runtime",
        "env": "PLCREX_KICODIA_PATH",
        "candidates": (
            "vendor/runtime-tools/kicodia/kicodia-win.bat",
            "vendor/runtime-tools/kicodia-win.bat",
        ),
    },
}


def get_repo_root() -> Path:
    """Return the repository root."""

    return Path(__file__).resolve().parents[3]


def get_default_plcrex_python() -> str:
    """Return the preferred Python executable for PLCreX."""

    if os.name == "nt":
        candidate = get_repo_root() / ".venv-plcrex" / "Scripts" / "python.exe"
    else:
        candidate = get_repo_root() / ".venv-plcrex" / "bin" / "python"
    return str(candidate) if candidate.exists() else sys.executable


def get_runtime_temp_root() -> Path:
    """Return the local temp root used for PLCreX executions."""

    configured = os.getenv(RUNTIME_TEMP_ENV)
    temp_root = Path(configured) if configured else Path.cwd() / ".tmp" / "plcrex-runtime"
    temp_root.mkdir(parents=True, exist_ok=True)
    return temp_root


def resolve_runtime_tool(tool_name: str | None) -> Path | None:
    """Resolve a backend-managed external runtime binary/script."""

    if not tool_name:
        return None

    config = RUNTIME_TOOL_CONFIG.get(tool_name)
    if not config:
        return None

    env_name = str(config["env"])
    configured = os.getenv(env_name)
    if configured:
        candidate = Path(configured).expanduser()
        if candidate.exists():
            return candidate

    for relative in config["candidates"]:
        candidate = get_repo_root() / str(relative)
        if candidate.exists():
            return candidate

    return None


def get_runtime_tool_label(tool_name: str | None) -> str | None:
    """Return a human-readable runtime tool label."""

    if not tool_name:
        return None
    config = RUNTIME_TOOL_CONFIG.get(tool_name)
    if not config:
        return None
    return str(config["label"])


def get_vendor_path() -> Path | None:
    """Return the vendor checkout path if it exists."""

    candidate = os.getenv(VENDOR_ENV)
    if candidate:
        candidate_path = Path(candidate)
        if candidate_path.exists():
            return candidate_path

    default = get_repo_root() / "vendor" / "PLCreX"
    return default if default.exists() else None


def require_vendor_path() -> Path:
    """Return the PLCreX vendor path or raise a backend error."""

    vendor_path = get_vendor_path()
    if vendor_path is None:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="PLCreX vendor checkout is missing on the backend.",
        )
    return vendor_path


def build_env() -> dict[str, str]:
    """Build an environment ensuring PLCreX is on PYTHONPATH when installed from vendor."""

    env = os.environ.copy()
    env.setdefault("PYTHONIOENCODING", "utf-8")
    env.setdefault("PYTHONUTF8", "1")
    env.setdefault("TERM", "dumb")
    env.setdefault("NO_COLOR", "1")
    env.setdefault("CLICOLOR", "0")
    env.setdefault("FORCE_COLOR", "0")
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
    return [get_default_plcrex_python(), "-m", "plcrex", "--help"]


def build_run_command() -> list[str]:
    """Return the PLCreX base command without help arguments."""

    help_command = build_help_command()
    if help_command[-1:] == ["--help"]:
        return help_command[:-1]
    return [get_default_plcrex_python(), "-m", "plcrex"]


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
        message = normalize_plcrex_error(stderr or "PLCreX help command failed")
        logger.error(
            "PLCreX help command failed with return code %s. stderr=%s stdout=%s",
            exc.returncode,
            stderr,
            exc.stdout.strip() if exc.stdout else "",
        )
        raise PlcrexCommandError(message) from exc

    logger.info("PLCreX help command completed successfully")
    return completed.stdout or ""


def normalize_plcrex_error(message: str) -> str:
    """Improve common PLCreX runtime errors with actionable guidance."""

    if "io_analysis.cp39" in message or "plcrex.tools.fbdia.pyd.io_analysis" in message:
        return (
            "PLCreX was bootstrapped with an incompatible Python version. "
            "Its Windows binary modules require Python 3.9. Recreate `.venv-plcrex` "
            "with Python 3.9 and run `just pull-plcrex` again."
        )
    return message


def summarize_execution_failure(command_name: str, stderr: str, stdout: str) -> str:
    """Convert raw PLCreX process output into a short safe frontend message."""

    combined = "\n".join(part for part in (stderr, stdout) if part).strip()

    if "ParseError" in combined or "ElementTree" in combined:
        return "PLCreX could not parse the uploaded XML file. Check that it is a valid PLCopen XML input for this command."
    if "No such file or directory" in combined or "FileNotFoundError" in combined:
        return "PLCreX could not find a required runtime file while executing this command."
    if "PermissionError" in combined:
        return "PLCreX could not access a required file or directory while executing this command."
    if "UnicodeDecodeError" in combined or "UnicodeEncodeError" in combined:
        return "PLCreX failed because of a text encoding problem in the input or runtime environment."
    if "AssertionError" in combined:
        return f"PLCreX reported an internal assertion failure while running `{command_name}`."
    return f"PLCreX failed while running `{command_name}`. Check that the uploaded file matches the command input format."


def read_plcrex_cli_source() -> str:
    """Read the PLCreX CLI source as a fallback for command discovery."""

    vendor_path = get_vendor_path()
    if not vendor_path:
        raise PlcrexCommandError("PLCreX vendor checkout not found.")

    cli_path = vendor_path / "plcrex" / "cli.py"
    if not cli_path.exists():
        raise PlcrexCommandError(f"PLCreX CLI source not found: {cli_path}")

    return cli_path.read_text(encoding="utf-8", errors="replace")


def parse_commands_from_cli_source(source: str) -> list[PlcrexCommand]:
    """Extract command names and summaries from the PLCreX CLI source."""

    pattern = re.compile(
        r'@app\.command\("(?P<name>[^"]+)"\)[^\n]*\n'
        r'def\s+\w+\(.*?\):\s*'
        r'"""\s*(?P<summary>[^"\n]+?)\s*"""',
        re.DOTALL,
    )
    commands: list[PlcrexCommand] = []
    for match in pattern.finditer(source):
        name = match.group("name").strip()
        raw_summary = re.sub(r"\s+", " ", match.group("summary")).strip()
        parts = [part.strip() for part in raw_summary.split(r"\t") if part.strip()]
        if len(parts) == 1:
            parts = [part.strip() for part in re.split(r"\s{2,}", raw_summary) if part.strip()]
        display_summary = parts[0] if parts else raw_summary
        io = None
        for candidate in parts[1:]:
            if candidate.startswith("*"):
                io = candidate
                break
        commands.append(build_command_model(name=name, summary=display_summary, io=io))
    return commands


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
        if line.startswith(TABLE_SECTION_EDGES):
            break
        if not line.startswith(TABLE_ROW_PREFIXES):
            continue

        content = line.strip("|│").strip()
        if not content or content.startswith(("-", "─")):
            continue

        parts = [segment.strip() for segment in re.split(r"\s{2,}", content) if segment.strip()]
        if not parts:
            continue
        name = parts[0]
        summary = parts[1] if len(parts) > 1 else ""
        io = parts[2] if len(parts) > 2 else None
        commands.append(build_command_model(name=name, summary=summary, io=io))

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
        commands.append(build_command_model(name=name, summary=summary))
    return commands


def build_command_model(name: str, summary: str, io: str | None = None) -> PlcrexCommand:
    """Combine parsed help output with local command metadata."""

    spec = COMMAND_SPECS.get(name, CommandSpec())
    accepts_upload = getattr(spec, "accepts_upload", True)
    unsupported_reason = spec.unsupported_reason
    if spec.runtime_tool:
        runtime_path = resolve_runtime_tool(spec.runtime_tool)
        if runtime_path is None:
            accepts_upload = False
            runtime_label = get_runtime_tool_label(spec.runtime_tool) or "Required backend runtime"
            unsupported_reason = f"{runtime_label} is not installed on the server yet."
    return PlcrexCommand(
        name=name,
        summary=summary,
        io=io,
        accepts_upload=accepts_upload,
        accepted_extensions=list(spec.input_extensions),
        output_extensions=list(spec.output_extensions),
        extra_path_label=None,
        extra_path_placeholder=None,
        unsupported_reason=unsupported_reason,
        options=[
            PlcrexOption(
                name=option.name,
                label=option.label,
                description=option.description,
                default=option.default,
            )
            for option in spec.option_specs
        ],
    )


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

    try:
        output = read_plcrex_help()
        commands = parse_plcrex_help(output)
        if commands:
            return tuple(commands)
    except PlcrexCommandError as exc:
        logger.warning("Falling back to PLCreX CLI source parsing after help failure: %s", exc)

    commands = parse_commands_from_cli_source(read_plcrex_cli_source())
    if not commands:
        raise PlcrexCommandError("Unable to parse PLCreX command metadata.")
    return tuple(commands)


def get_plcrex_commands(force_refresh: bool = False) -> list[PlcrexCommand]:
    """Return PLCreX commands, optionally forcing a refresh."""

    if force_refresh:
        cached_plcrex_commands.cache_clear()
    try:
        return list(cached_plcrex_commands())
    except PlcrexCommandError as exc:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc


def get_command_spec(command_name: str) -> CommandSpec:
    """Return the execution spec for a PLCreX command."""

    for command in get_plcrex_commands():
        if command.name == command_name:
            return COMMAND_SPECS.get(command_name, CommandSpec())
    raise HTTPException(status.HTTP_404_NOT_FOUND, detail=f"Unknown PLCreX command: {command_name}")


def parse_option_values(raw_options: str | None) -> dict[str, bool]:
    """Decode frontend options from JSON."""

    if not raw_options:
        return {}
    try:
        parsed = json.loads(raw_options)
    except json.JSONDecodeError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Invalid option payload.") from exc
    if not isinstance(parsed, list):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Options must be a JSON array.")

    values: dict[str, bool] = {}
    for entry in parsed:
        if not isinstance(entry, dict):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Each option must be an object.")
        name = entry.get("name")
        value = entry.get("value")
        if not isinstance(name, str) or not isinstance(value, bool):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Invalid option entry.")
        values[name] = value
    return values


async def write_upload(upload: UploadFile, target: Path) -> None:
    """Persist an uploaded file to disk."""

    data = await upload.read()
    target.write_bytes(data)


def validate_upload(upload: UploadFile | None, spec: CommandSpec) -> str | None:
    """Validate upload presence and extension."""

    accepts_upload = getattr(spec, "accepts_upload", True)
    if not accepts_upload:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail=spec.unsupported_reason or "This PLCreX command is not file-upload based.",
        )

    if upload is None or not upload.filename:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Please upload a file before running PLCreX.")

    suffix = Path(upload.filename).suffix.lower()
    if spec.input_extensions and suffix not in spec.input_extensions:
        allowed = ", ".join(spec.input_extensions)
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail=f"Wrong file format. Expected one of: {allowed}.",
        )
    return suffix


def resolve_required_runtime_path(spec: CommandSpec) -> Path | None:
    """Resolve required backend-managed runtime tools for a command."""

    if not spec.runtime_tool:
        return None

    resolved = resolve_runtime_tool(spec.runtime_tool)
    if resolved is None:
        runtime_label = get_runtime_tool_label(spec.runtime_tool) or "Required backend runtime"
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"{runtime_label} is not installed on the backend.",
        )
    return resolved


def build_export_stub(staging_dir: Path, input_filename: str) -> tuple[Path, Path]:
    """Create predictable input/output locations inside the temp workspace."""

    source_dir = staging_dir / "input"
    output_dir = staging_dir / "output"
    source_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    return source_dir, output_dir


def build_command_args(
    command_name: str,
    spec: CommandSpec,
    source_path: Path,
    output_dir: Path,
    extra_path: Path | None,
    option_values: dict[str, bool],
) -> list[str]:
    """Build the subprocess argv for a PLCreX run."""

    base_name = source_path.stem
    output_stub = output_dir / base_name
    output_path = output_stub.with_suffix(spec.output_extensions[0]) if spec.output_extensions else output_stub

    args: list[str] = build_run_command() + [command_name]

    for option in spec.option_specs:
        enabled = option_values.get(option.name, option.default)
        if option.name == "txt" and not enabled:
            args.append("--no-txt")
            continue
        if option.name == "dot" and not enabled:
            args.append("--no-dot")
            continue
        if enabled:
            args.append(option.flag)

    if command_name in {"fbd-to-sctx", "fbd-to-st-ext", "iec-check"}:
        args.extend([str(source_path), str(extra_path), str(output_path)])
    elif command_name == "st-to-sctx":
        args.extend([str(source_path), str(output_path), str(extra_path)])
    elif command_name == "xml-validator":
        args.append(str(source_path))
    else:
        args.extend([str(source_path), str(output_path)])

    return args


def collect_outputs(output_dir: Path, spec: CommandSpec) -> list[PlcrexRunOutput]:
    """Read generated output files from the temp workspace."""

    collected: list[PlcrexRunOutput] = []
    candidate_dirs = [output_dir, output_dir / "PLCreX_outputs"]
    seen_paths: set[Path] = set()
    for candidate_dir in candidate_dirs:
        if not candidate_dir.exists():
            continue
        for file_path in sorted(candidate_dir.iterdir()):
            if not file_path.is_file() or file_path in seen_paths:
                continue
            seen_paths.add(file_path)
            if spec.output_extensions and file_path.suffix.lower() not in spec.output_extensions:
                continue
            collected.append(
                PlcrexRunOutput(
                    filename=file_path.name,
                    content=file_path.read_text(encoding="utf-8", errors="replace"),
                )
            )
    return collected


async def run_plcrex_command(
    command_name: str,
    upload: UploadFile | None,
    raw_options: str | None = None,
    extra_path: str | None = None,
) -> PlcrexRunResponse:
    """Execute PLCreX for an uploaded file and return structured results."""

    spec = get_command_spec(command_name)
    validate_upload(upload, spec)
    resolved_extra_path = resolve_required_runtime_path(spec)
    option_values = parse_option_values(raw_options)

    workspace = get_runtime_temp_root() / f"plcrex-web-{uuid4().hex}"
    workspace.mkdir(parents=True, exist_ok=False)
    try:
        source_dir, output_dir = build_export_stub(workspace, upload.filename if upload else "input")
        source_path = source_dir / Path(upload.filename or "input").name
        if upload is not None:
            await write_upload(upload, source_path)

        args = build_command_args(
            command_name=command_name,
            spec=spec,
            source_path=source_path,
            output_dir=output_dir,
            extra_path=resolved_extra_path,
            option_values=option_values,
        )

        logger.info("Running PLCreX command: %s", args)
        completed = subprocess.run(
            args,
            capture_output=True,
            env=build_env(),
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=require_vendor_path(),
        )

        stdout = (completed.stdout or "").strip()
        stderr = (completed.stderr or "").strip()
        outputs = collect_outputs(output_dir, spec)

        if completed.returncode != 0:
            logger.error(
                "PLCreX command failed: command=%s returncode=%s stdout=%s stderr=%s",
                command_name,
                completed.returncode,
                stdout,
                stderr,
            )
            detail = summarize_execution_failure(command_name=command_name, stderr=stderr, stdout=stdout)
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                detail={
                    "command": command_name,
                    "filename": upload.filename if upload else None,
                    "status": "error",
                    "stdout": "",
                    "stderr": "",
                    "outputs": [output.model_dump() for output in outputs],
                    "message": detail,
                },
            )

        if stdout and not outputs and (spec.uses_stdout or not spec.output_extensions):
            synthesized_name = "stdout.txt"
            if spec.output_extensions:
                synthesized_name = f"{source_path.stem}{spec.output_extensions[0]}"
            outputs = [PlcrexRunOutput(filename=synthesized_name, content=stdout)]

        return PlcrexRunResponse(
            command=command_name,
            filename=upload.filename if upload else None,
            status="success",
            stdout=stdout,
            stderr=stderr,
            outputs=outputs,
        )
    finally:
        shutil.rmtree(workspace, ignore_errors=True)
