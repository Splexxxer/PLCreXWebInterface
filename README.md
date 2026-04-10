# PLCreX Web Interface

This repository contains a small web interface for [PLCreX](https://github.com/marwern/PLCreX).  
It provides a FastAPI backend and a React/Vite frontend for exploring PLCreX commands and building a Windows-based runtime around them.

PLCreX upstream repository: https://github.com/marwern/PLCreX

## Installation

### Current scope
- Development is currently supported on Windows
- PLCreX runtime is currently Windows-only
- Docker is not a supported PLCreX runtime path at the moment

### Requirements
- Python installed
- Python 3.9 installed for PLCreX bootstrap
- Node.js and npm installed
- `just` installed
- Git for Windows installed
- NuSMV available as `NuSMV.exe` if you want `fbd-to-sctx` / `fbd-to-st-ext`
- IEC Checker available as `iec_checker_Windows_x86_64_v0.4.exe` if you want `iec-check`
- Kicodia available as `kicodia-win.bat` if you want `st-to-sctx`

### PowerShell setup
From the repository root:

```powershell
just create-python-env
.\.venv\Scripts\Activate.ps1
$env:Path = "C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;" + $env:Path
$env:PYTHON = "$PWD\.venv\Scripts\python.exe"
$env:PYTHON_BOOTSTRAP = "C:\Path\To\Python39\python.exe"
just install
just pull-plcrex
just stage-runtime-tools
just runtime-tools-status
just dev-up
```

`just pull-plcrex` now enforces Python 3.9 on Windows for the PLCreX bootstrap environment. If `PYTHON_BOOTSTRAP` points to Python 3.10+ or 3.8-, the command will fail early instead of creating a broken `.venv-plcrex`.

On Windows, the bootstrap script first tries the standard user install path:

```text
%LOCALAPPDATA%\Programs\Python\Python39\python.exe
```

If you prefer the Python launcher, `PYTHON_BOOTSTRAP="py -3.9"` is also supported.

### Backend runtime tools
Commands such as `fbd-to-sctx`, `fbd-to-st-ext`, `iec-check`, and `st-to-sctx` depend on external binaries that must be present on the backend as part of a complete local dev setup. The browser UI does not ask the user for these paths anymore.

Useful commands:

```powershell
just stage-runtime-tools
just runtime-tools-status
```

PLCreX’s own installation guide lists these as external tools called by PLCreX and also points to where developers should download them:

- IEC-Checker v0.4 via GitHub: https://plcrex.readthedocs.io/en/latest/install.html
- NuSMV v2.6.0 via the NuSMV homepage: https://plcrex.readthedocs.io/en/latest/install.html
- Kicodia via KIELER’s download page: https://plcrex.readthedocs.io/en/latest/install.html

Recommended dev setup:

1. Follow the PLCreX installation page to download the external tools.
2. Keep the extracted/runtime files locally on your machine.
3. Run `just runtime-tools-status`.
4. Run `just stage-runtime-tools`.
5. If auto-discovery still does not find one of them, set the matching `PLCREX_*_SOURCE` env var and run `just stage-runtime-tools` again.

`just pull-plcrex` first tries to auto-discover them from common Windows install paths and from already-staged files under `vendor/runtime-tools/`.

If auto-discovery does not find them, you can provide explicit paths before running `just pull-plcrex`:

```powershell
$env:PLCREX_NUSMV_SOURCE = "C:\path\to\NuSMV.exe"
$env:PLCREX_IEC_CHECKER_SOURCE = "C:\path\to\iec_checker_Windows_x86_64_v0.4.exe"
$env:PLCREX_KICODIA_SOURCE = "C:\path\to\kicodia-win.bat"
just pull-plcrex
```

Do not paste placeholder paths like `C:\path\to\NuSMV.exe` into your shell. If a configured path is a placeholder or does not exist, the pull step now skips staging that tool with a warning instead of failing the whole bootstrap.

The pull step copies discovered tools into backend-managed locations under `vendor/runtime-tools/`, and the FastAPI backend auto-detects them from there. If a required runtime tool is still missing, the corresponding command is shown as unavailable in the frontend instead of prompting the browser user for a filesystem path.

#### Developer install steps

Install the external tools on your Windows machine first, then stage them for this repo.

1. Install NuSMV and make sure you have a real `NuSMV.exe`.
2. Install IEC Checker and make sure you have a real `iec_checker_Windows_x86_64_v0.4.exe` or equivalent `iec_checker.exe`.
3. Install Kicodia and make sure you have a real `kicodia-win.bat`.
4. Run:

```powershell
just runtime-tools-status
just stage-runtime-tools
just runtime-tools-status
```

5. If auto-discovery does not find one of them, set the explicit path and run staging again:

```powershell
$env:PLCREX_NUSMV_SOURCE = "C:\real\path\to\NuSMV.exe"
$env:PLCREX_IEC_CHECKER_SOURCE = "C:\real\path\to\iec_checker_Windows_x86_64_v0.4.exe"
$env:PLCREX_KICODIA_SOURCE = "C:\real\path\to\kicodia-win.bat"
just stage-runtime-tools
```

You can also place the tools directly into the repo-managed default folders before staging:

```text
vendor/runtime-tools/nusmv/NuSMV.exe
vendor/runtime-tools/iec-checker/iec_checker_Windows_x86_64_v0.4.exe
vendor/runtime-tools/kicodia/kicodia-win.bat
```

Those are the default backend locations and are the right paths to preserve later if these runtimes are folded into the Docker image build.

After staging, the backend expects these files under:

```text
vendor/runtime-tools/nusmv/NuSMV.exe
vendor/runtime-tools/iec-checker/iec_checker_Windows_x86_64_v0.4.exe
vendor/runtime-tools/kicodia/kicodia-win.bat
```

If one of these tools is still missing, only the PLCreX commands that depend on it will be unavailable in the frontend.

Then open:
- Frontend: `http://127.0.0.1:5173`
- Backend docs: `http://127.0.0.1:8000/docs`
- Backend health: `http://127.0.0.1:8000/health`

Stop the dev servers with:

```powershell
just dev-down
```

## Notes

If PowerShell resolves `bash` to WSL instead of Git Bash, run:

```powershell
$env:Path = "C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;" + $env:Path
```

If `plcrex --help` fails because of the `io_analysis` module, recreate `.venv-plcrex` with Python 3.9:

```powershell
Remove-Item -Recurse -Force .venv-plcrex -ErrorAction SilentlyContinue
$env:PYTHON_BOOTSTRAP = "C:\Path\To\Python39\python.exe"
just pull-plcrex
```

You can test the PLCreX CLI directly with:

```powershell
.\.venv-plcrex\Scripts\python.exe -m plcrex --help
```
