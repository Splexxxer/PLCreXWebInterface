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
- Run `just pull-plcrex` (or `./scripts/pull_plcrex.sh`) to clone/update `vendor/PLCreX/` from `https://github.com/marwern/PLCreX`.
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
   just frontend-dev   # Vite dev server
   just backend-dev    # FastAPI + Uvicorn with reload
   just frontend-build # Production build artifacts
   just dev-up         # Run backend + frontend dev servers together
   just dev-up-build   # Rebuild frontend, then launch both dev servers
   just docker-build   # Pulls PLCreX, builds the container image
   just docker-run     # Runs the previously built container
   ```

The FastAPI app exposes `/health` plus `/api/status` and is already wired to serve the `frontend/dist` bundle once it exists.

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
just docker-run
```
`just docker-build` automatically refreshes the vendor checkout before invoking `docker build`, so the runtime image always has an updated PLCreX payload ready for future wiring.

## Notes
- No database, authentication, or PLCreX execution paths are implemented yet.
- Browser history, PLCreX process control, and upload features are intentionally left out for now.
- `vendor/PLCreX/` stays gitignored—only initialization scripts ever touch it.
