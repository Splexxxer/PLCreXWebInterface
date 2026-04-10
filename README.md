# PLCreX Web Interface

Minimal FastAPI + React/Vite workspace for building a web console around PLCreX without committing the PLCreX runtime to this repository.

## Stack
- Frontend: React, TypeScript, Vite, Tailwind CSS
- Backend: FastAPI served by Uvicorn
- Tooling: `just`, Bash scripts, Docker, Syft

## Repository Layout
```text
backend/   FastAPI application
frontend/  React + Vite frontend
scripts/   Setup and packaging helpers
vendor/    Gitignored third-party checkouts
docs/      Project documentation
```

## Prerequisites

### All environments
- Python installed and available on `PATH`
- Node.js and npm installed
- `just` installed
- `bash` available

### Windows development
The development workflow in this repository is verified on Windows with PowerShell plus Git for Windows.

You need:
- Git for Windows installed
- `bash.exe` from Git for Windows available before the WSL `bash.exe` shim on `PATH`
- A Python 3.9 interpreter available for PLCreX bootstrap on Windows

For the current PowerShell session:
```powershell
$env:Path = "C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;" + $env:Path
```

Verify it:
```powershell
bash --version
just --version
py -0p
```

If `bash --version` prints a WSL error instead of GNU Bash output, PowerShell is still resolving `bash` to `C:\Users\<you>\AppData\Local\Microsoft\WindowsApps\bash.exe`.

`py -0p` should show a Python 3.9 installation path for PLCreX. The main app environment can use a newer Python, but the current PLCreX Windows setup needs Python 3.9 because the upstream checkout includes a compiled `cp39` module.

### Linux, macOS, and WSL
The `Justfile` is written for `bash`, so these environments should use the same commands below as long as `bash`, `python3` or `python`, `npm`, and `just` are installed.

This workflow was verified in this repository on Windows. Non-Windows development is expected to work, but is not yet verified here.

## Quick Start

### Windows PowerShell
From the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
$env:Path = "C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;" + $env:Path
$env:PYTHON = "$PWD\.venv\Scripts\python.exe"
just install
$env:PYTHON_BOOTSTRAP = "C:\Path\To\Python39\python.exe"
just pull-plcrex
just dev-up
```

Then open:
- Frontend dev server: `http://127.0.0.1:5173`
- Backend API docs: `http://127.0.0.1:8000/docs`
- Backend health endpoint: `http://127.0.0.1:8000/health`

Stop both dev servers with:
```powershell
just dev-down
```

### Linux, macOS, or WSL
From the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
export PYTHON="$PWD/.venv/bin/python"
just install
just pull-plcrex
just dev-up
```

Stop both dev servers with:
```bash
just dev-down
```

## What The Commands Do
- `just install`
  Installs backend Python dependencies into the main project virtual environment and installs frontend npm dependencies.
- `just pull-plcrex`
  Clones a fresh `vendor/PLCreX/`, creates a separate `.venv-plcrex/`, installs PLCreX dependencies there, and installs PLCreX editable.
- `just dev-up`
  Starts the Vite frontend and FastAPI backend together.

The PLCreX source is not committed to this repository. It always lives in the gitignored `vendor/PLCreX/` checkout.

## PLCreX Environment Layout
PLCreX is intentionally isolated from the main app environment:
- App/backend environment: `.venv`
- PLCreX environment: `.venv-plcrex`

The backend development commands automatically point `/api/commands` at `.venv-plcrex` by setting `PLCREX_HELP_COMMAND`.

Inspect PLCreX help directly with:

### Windows
```powershell
.\.venv-plcrex\Scripts\python.exe -m plcrex --help
```

### Linux, macOS, or WSL
```bash
./.venv-plcrex/bin/python -m plcrex --help
```

## Frontend Build
Build the production frontend bundle with:

```bash
just frontend-build
```

After that, `just backend-dev` can serve `frontend/dist` directly through FastAPI.

## Common Problems

### `bash` prints a WSL error on Windows
PowerShell is finding the WSL shim instead of Git Bash.

For the current shell:
```powershell
$env:Path = "C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;" + $env:Path
```

Then verify:
```powershell
bash --version
```

### `just install` cannot find Python
Set `PYTHON` explicitly before running `just`.

Windows:
```powershell
$env:PYTHON = "$PWD\.venv\Scripts\python.exe"
```

Linux, macOS, or WSL:
```bash
export PYTHON="$PWD/.venv/bin/python"
```

### PLCreX dependency conflicts with the app environment
Do not install PLCreX into `.venv`. The repository setup now uses your main interpreter only to bootstrap `.venv-plcrex`, then installs PLCreX there.

### `plcrex --help` fails with `ModuleNotFoundError` for `io_analysis`
On Windows, the current upstream PLCreX checkout includes `plcrex/tools/fbdia/pyd/io_analysis.cp39-win_amd64.pyd`, so `.venv-plcrex` must be built with Python 3.9.

Fix it by recreating the PLCreX environment with a Python 3.9 bootstrap interpreter:

```powershell
Remove-Item -Recurse -Force .venv-plcrex -ErrorAction SilentlyContinue
$env:PYTHON_BOOTSTRAP = "C:\Path\To\Python39\python.exe"
just pull-plcrex
```

## Other Useful Commands
```bash
just frontend-dev
just backend-dev
just frontend-build
just package
just docker-build
just docker-build-upgrade
just docker-run
just down
```

## Packaging
`just package` runs `scripts/package_app.sh`, which currently:
1. refreshes the PLCreX checkout,
2. builds the frontend,
3. copies backend, frontend, and vendor assets into `.build/package/`,
4. generates an SBOM if Syft is installed.

## Current Scope
- No database
- No authentication
- No persistent backend job state
- No live PLCreX streaming or background worker system
- `vendor/PLCreX/` remains gitignored
