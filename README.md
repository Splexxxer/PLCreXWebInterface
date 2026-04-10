# PLCreX Web Interface

Minimal FastAPI + React/Vite workspace for building a web console around PLCreX without committing the runtime itself.

## Stack
- **Frontend:** React, TypeScript, Vite, Tailwind CSS
- **Backend:** FastAPI on Python 3.12 served by Uvicorn
- **Tooling:** `just`, shell scripts, Docker, Syft (for SBOM generation)

## Repository layout
```
backend/   FastAPI application (health endpoint, API router placeholder, frontend serving helper)
frontend/  Vite React app ready for Tailwind + sessionStorage work later
scripts/   Utility scripts for pulling PLCreX and staging future packages
vendor/    Gitignored third-party checkouts (PLCreX lives here when pulled)
```

## PLCreX vendor checkout
- The PLCreX source is **not** part of this repository.
- Run `just pull-plcrex` (or `./scripts/pull_plcrex.sh`) to clone a fresh `vendor/PLCreX/` from `https://github.com/marwern/PLCreX`, install the exact PLCreX dependency set from its `requirements.txt`, and then install PLCreX editable. Every run wipes and recreates both the vendor checkout and the repo-local `.venv-plcrex/`, guaranteeing a clean toolchain; set `PYTHON=/path/to/python` if you want to opt out, or `PLCREX_VENV=/different/path` to relocate the managed venv. The helper also force-installs a modern `setuptools` and injects the Python user-site plus vendor path into `PYTHONPATH` so packages such as `dd` (which import `pkg_resources` during build) succeed even when your interpreter defaults to user installs.
- The folder stays gitignored so the upstream code never lands in commits.

## Development workflow
1. **Backend deps**
   ```bash
   cd backend
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   ```
2. **Frontend deps**
   ```bash
   cd frontend
   npm install
   ```
3. **Just recipes** (override `PYTHON`, `NPM`, `UVICORN_HOST`, or `UVICORN_PORT` to customize shells/hosts)
   ```bash
   just install       # Install backend Python deps, frontend npm deps, and PLCreX CLI in one go
   just frontend-dev   # Vite dev server
   just backend-dev    # FastAPI + Uvicorn with reload
   just frontend-build # Production build artifacts
   just dev-up         # Run backend + frontend dev servers together
   just dev-up-build   # Rebuild frontend, then launch both dev servers
   just dev-down       # Stop the dev servers started via dev-up
   just docker-build   # Builds using the current PLCreX checkout (clones if missing)
   just docker-build-upgrade # Pulls newest PLCreX, then builds the container image
   just docker-run     # Runs the previously built container
   just down           # Stops the running docker container
   ```

The FastAPI app exposes `/health` plus `/api/status` and `/api/commands` and is already wired to serve the `frontend/dist` bundle once it exists.
`/api/commands` shells out to `plcrex --help`, parses the command table, and returns the available PLCreX commands so the frontend can stay synchronized with whatever version is pulled into `vendor/PLCreX/`.
Override the command or vendor location with `PLCREX_HELP_COMMAND` / `PLCREX_VENDOR_PATH` if your runtime wiring differs from the defaults.
`just dev-up` writes PID data to `.devserver-pids` so that `just dev-down` can gracefully stop both dev servers from a separate shell.

## Packaging + SBOM
- `just package` runs `scripts/package_app.sh`, which currently:
  1. pulls/updates PLCreX,
  2. builds the frontend,
  3. copies backend + frontend + vendor assets into `.build/package/`,
  4. generates an SBOM with Syft when available (prints a hint otherwise).
- Extend that script later with container builds or archives as needed.

## Docker image scaffold
```
just docker-build
just docker-build-upgrade
just docker-run
just down
```
`just docker-build` leaves your existing `vendor/PLCreX` untouched (cloning only when it is absent) so you can build images from a specific commit. Run `just docker-build-upgrade` when you want to refresh the checkout before building.
`just docker-run` launches the container as `plcrex-web-dev` (override with `DOCKER_CONTAINER_NAME=...`). Run `just down` from another shell to stop it.

## Notes
- No database, authentication, or PLCreX execution paths are implemented yet.
- Browser history, PLCreX process control, and upload features are intentionally left out for now.
- `vendor/PLCreX/` stays gitignored—only initialization scripts ever touch it.
