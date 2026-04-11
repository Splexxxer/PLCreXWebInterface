# PLCreX Web Interface

This repository contains a small web interface for [PLCreX](https://github.com/marwern/PLCreX).
It provides a FastAPI backend and a React/Vite frontend for exploring PLCreX commands and building a Windows-based runtime around them.

PLCreX upstream repository: https://github.com/marwern/PLCreX

## Installation

### Current scope
- Runtime is currently Windows-only
- Docker packaging targets Windows containers only
- Local source development is currently supported on Windows

### Docker installation

This is the primary installation path for end users. You do not need this repository to run the packaged app.

Requirements:
- Docker Desktop installed
- Docker Desktop switched to Windows container mode
- the released Windows image archive downloaded locally

Steps:

1. Download the release assets:
   - `plcrex-web-windows-ltsc2022.tar`
2. Switch Docker Desktop to Windows containers.
3. Load the image archive:

```powershell
docker load --input .\plcrex-web-windows-ltsc2022.tar
```

4. Start the container:

```powershell
docker run -d --name plcrex-web -p 8000:8000 plcrex-web:windows-ltsc2022
```

5. Open the app:
   - UI: `http://127.0.0.1:8000`
   - API docs: `http://127.0.0.1:8000/docs`
   - Health: `http://127.0.0.1:8000/health`

Useful Docker commands:

```powershell
docker ps
docker logs --tail 100 plcrex-web
docker stop plcrex-web
docker rm plcrex-web
```

The SBOM file records:
- the PLCreX version inside the image
- the PLCreX commit used to build it
- the `PLCreXWebInterface` repo commit used to create the image

### Docker installation notes

- If Docker reports that the server OS is `linux`, Docker Desktop is in the wrong mode. Switch to Windows containers and run the image again.
- If you want to run the app on a different port, change the left side of `-p`, for example `-p 8080:8000`.
- If a container with the same name already exists, remove it first with `docker rm -f plcrex-web`.

## Dev Installation

This path is for working on the source code, rebuilding the frontend, or creating new Windows image archives from this repository.

### Dev requirements
- Python installed
- Python 3.9 installed for PLCreX bootstrap
- Node.js and npm installed
- `just` installed
- Git for Windows installed
- Docker Desktop installed and switched to Windows container mode if you want to build/run the container image
- NuSMV available as `NuSMV.exe` if you want `fbd-to-sctx` / `fbd-to-st-ext`
- IEC Checker available as `iec_checker_Windows_x86_64_v0.4.exe` if you want `iec-check`
- Kicodia available as `kicodia-win.bat` if you want `st-to-sctx`

### Dev PowerShell setup
From the repository root:

```powershell
just create-python-env
.\.venv\Scripts\Activate.ps1
$env:Path = "C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;" + $env:Path
$env:PYTHON = "$PWD\.venv\Scripts\python.exe"
$env:PYTHON_BOOTSTRAP = "C:\Path\To\Python39\python.exe"
just install
just pull-plcrex
just dev-up
```

`just pull-plcrex` enforces Python 3.9 on Windows for the PLCreX bootstrap environment. If `PYTHON_BOOTSTRAP` points to Python 3.10+ or 3.8-, the command fails early instead of creating a broken `.venv-plcrex`.

On Windows, the bootstrap script first tries the standard user install path:

```text
%LOCALAPPDATA%\Programs\Python\Python39\python.exe
```

If you prefer the Python launcher, `PYTHON_BOOTSTRAP="py -3.9"` is also supported.

### Dev runtime tools
Commands such as `fbd-to-sctx`, `fbd-to-st-ext`, `iec-check`, and `st-to-sctx` depend on external binaries that must be present on the backend as part of a complete local dev setup. The browser UI does not ask the user for these paths anymore.

PLCreX's own installation guide lists these as external tools called by PLCreX and points to where developers should download them:

- IEC-Checker v0.4 via GitHub: https://plcrex.readthedocs.io/en/latest/install.html
- NuSMV v2.6.0 via the NuSMV homepage: https://plcrex.readthedocs.io/en/latest/install.html
- Kicodia via KIELER's download page: https://plcrex.readthedocs.io/en/latest/install.html

Recommended dev setup:

1. Follow the PLCreX installation page to download the external tools.
2. Copy the runtime files into this repo under:

```text
vendor/runtime-tools/nusmv/NuSMV.exe
vendor/runtime-tools/iec-checker/iec_checker_Windows_x86_64_v0.4.exe
vendor/runtime-tools/kicodia/kicodia-win.bat
```

3. Start the app with `just dev-up`.

The FastAPI backend auto-detects those repo-local paths. If a required runtime tool is missing, only the PLCreX commands that depend on it will be unavailable in the frontend.

Then open:
- Frontend: `http://127.0.0.1:5173`
- Backend docs: `http://127.0.0.1:8000/docs`
- Backend health: `http://127.0.0.1:8000/health`

Stop the dev servers with:

```powershell
just dev-down
```

## Windows Container Image Build

The Docker image now targets Windows containers so the packaged runtime stays aligned with the Windows-only PLCreX toolchain.

### What goes into the image

The image build uses the repository `Dockerfile` and packages:

- the backend and frontend from this repository
- the pulled PLCreX checkout under `vendor/PLCreX`
- any runtime tools you placed under `vendor/runtime-tools/`

If you want NuSMV, IEC Checker, or Kicodia available inside the image, place them in the repo before building:

```text
vendor/runtime-tools/nusmv/NuSMV.exe
vendor/runtime-tools/iec-checker/iec_checker_Windows_x86_64_v0.4.exe
vendor/runtime-tools/kicodia/kicodia-win.bat
```

### Build prerequisites

1. Start Docker Desktop.
2. Switch Docker Desktop to Windows containers.
3. Make sure `vendor/PLCreX` exists by running `just pull-plcrex`.
4. Place any external runtime tools you want included under `vendor/runtime-tools/`.

### Build the image

Build and export the image with:

```powershell
just docker-build
```

`just docker-build` calls [scripts/docker_build_image.ps1](C:/Users/Marce/PycharmProjects/PLCreXWebInterface/scripts/docker_build_image.ps1:1). That script:

1. Builds the Windows image `plcrex-web:windows-ltsc2022`
2. Exports it to an untracked archive under:

```text
image_output/plcrex-web-windows-ltsc2022.tar
```

If the archive already exists, it is replaced.

You can override the defaults with environment variables:

```powershell
$env:DOCKER_IMAGE_NAME = "my-plcrex-web"
$env:DOCKER_IMAGE_TAG = "windows-custom"
$env:IMAGE_OUTPUT_DIR = "image_output"
just docker-build
```

### Run the built image locally

Run the built Windows container with:

```powershell
just docker-run
```

Optional overrides:

```powershell
$env:DOCKER_CONTAINER_NAME = "plcrex-web-dev"
$env:DOCKER_PORT = "8000"
just docker-run
```

### Troubleshooting

If Docker reports that the server OS is `linux`, Docker Desktop is in the wrong mode for this image. Switch to Windows containers and rerun the command.

If `just docker-build` fails before the build starts:

- `vendor/PLCreX` is missing: run `just pull-plcrex`
- Docker is not running: start Docker Desktop
- Docker is in Linux container mode: switch to Windows containers
- the `Dockerfile` is missing or renamed: update `scripts/docker_build_image.ps1` or restore the file

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
