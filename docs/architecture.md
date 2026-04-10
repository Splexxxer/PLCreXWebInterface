# architecture.md

## 1. Purpose

This document defines the base architecture of the project and is intended to be used as the initialization reference for the repository.

The project is a minimal web interface around **PLCreX**. The backend does not implement its own domain logic for PLC analysis. Its job is only to:

- accept input from the web UI,
- start a PLCreX process,
- wait for completion,
- return result or error output.

The project must stay small, predictable, and easy to initialize. Avoid unnecessary abstraction, infrastructure, and dependencies.

---

## 2. Design Principles

### Mandatory constraints
- No database
- No user accounts
- No persistent backend state
- No background worker system
- No websocket infrastructure
- No live log streaming
- No PLCreX source code committed into this repository
- No build orchestration beyond simple file-based commands

### Desired properties
- Minimal stack
- Single-container runtime
- Clear separation between build/init logic and runtime application logic
- Repo contains only the web project source code and build scripts
- PLCreX is pulled on demand into a gitignored vendor folder

---

## 3. Recommended Tech Stack

This is the approved base stack for the project.

### Frontend
- **React**
- **TypeScript**
- **Vite**
- **Tailwind CSS**

Why:
- React is the preferred UI framework for this project.
- Vite keeps the frontend setup lean and fast.
- TypeScript provides predictable structure without adding significant overhead.
- Tailwind is sufficient for a clean UI without introducing a larger component framework.

### Backend
- **Python 3.12**
- **FastAPI**
- **Uvicorn**

Why:
- PLCreX is Python-based, so Python is the most compatible backend choice.
- FastAPI is simple and appropriate for a small HTTP API plus static file serving.
- The backend only needs to spawn PLCreX processes and return results.

### Build / Packaging
- **Docker**
- **Justfile**
- **Shell script** for packaging
- **Syft** for SBOM generation

Why:
- The build pipeline should stay simple and command-driven.
- `just` provides a small command entrypoint without introducing a larger task runner.
- The packaging script should combine the web app and pulled PLCreX checkout into one runtime image.
- SBOM generation is required as part of packaging.

---

## 4. High-Level Architecture

The system has **two clearly separated parts**.

## Part A: Initialization and Packaging

This part is used by developers and CI-like local workflows to prepare the runtime artifact.

It is responsible for:
- pulling the newest PLCreX source into a local vendor folder,
- building the frontend,
- assembling the runtime Docker image,
- generating the SBOM.

This part is **not** runtime application logic.

## Part B: Runtime Application

This is the actual web application that runs inside the final container.

It is responsible for:
- serving the frontend,
- accepting uploads,
- starting PLCreX processes,
- returning results,
- returning error output when a process fails.

This part must stay small and should not contain packaging logic.

**Rule:** Do not mix Part A and Part B responsibilities in code organization.

---

## 5. Repository Scope

The repository must contain **only the web project source code and supporting build files**.

### Included in repository
- frontend source code
- backend source code
- Justfile
- shell packaging scripts
- Dockerfile(s)
- configuration files
- documentation

### Excluded from repository
- PLCreX checkout
- generated build artifacts
- temporary runtime files
- local packaging output

### PLCreX vendor location
```text
vendor/PLCreX/
```

This directory:
- is pulled on demand from the upstream repository,
- must be listed in `.gitignore`,
- must not be treated as owned project source code.

---

## 6. Upstream PLCreX Source

### Upstream repository
PLCreX is pulled from:

```text
https://github.com/marwern/PLCreX
```

### Pull behavior
- The project does **not** pin a version by default.
- The pull command always fetches the **newest upstream version**.
- The pulled checkout exists only locally in `vendor/PLCreX/`.

### Required command behavior
A dedicated command must exist that pulls or refreshes the PLCreX checkout into `vendor/PLCreX/`.

This command must be exposed through the `Justfile`.

---

## 7. Runtime Model

The runtime model is intentionally simple.

### Container model
- One runtime container
- FastAPI serves both API and frontend
- PLCreX is available inside the same container
- Backend spawns PLCreX processes directly

### No extra runtime infrastructure
Do not add:
- Redis
- Celery
- RabbitMQ
- job queues
- process supervisors beyond what is required to run the app
- external state stores

### Execution flow
1. User uploads a file from the UI.
2. Backend receives the request.
3. Backend creates a temporary working directory.
4. Backend starts a PLCreX process.
5. Backend waits for process completion.
6. Backend returns either:
   - normal output/result, or
   - error output if the process fails.
7. Temporary files are cleaned up.

---

## 8. Frontend Architecture

### Frontend goals
The frontend should remain a small single-page application.

### Views
The app stays single-page, but may contain two simple UI states/views:
- **Main view**: upload + run
- **History view**: previously submitted jobs in the current browser session

A button-based switch such as `History` is sufficient.

### Input model
Primary input is:
- file upload

Secondary input is allowed:
- hidden or less prominent text input

The file upload path is the main path and should shape the UI.

### Runtime UI states
The UI should only show:
- idle
- running
- finished output
- error output

### PLCreX command catalog
- The frontend must present available PLCreX commands/options dynamically.
- It should not hardcode the list because PLCreX versions can add or remove commands between releases.
- Fetch the command list from the backend at runtime before rendering relevant controls.
- A refresh button or automatic refresh on load is sufficient; no persistent caching is required on the client.

### Explicitly not required
- no live logs
- no streaming logs
- no partial log polling
- no terminal-like UI

### Browser-side history
History must be stored only in the browser.

#### Storage mechanism
- **sessionStorage**

#### Reason
- history should disappear when the browser session ends,
- backend remains effectively stateless,
- no database is introduced.

#### History scope
Store only lightweight metadata needed for the UI, for example:
- local job id
- original filename
- timestamp
- status

Do not treat browser history as an authoritative backend record.

---

## 9. Backend Architecture

### Responsibilities
The backend has these responsibilities only:
- serve the frontend build,
- expose a small HTTP API,
- spawn PLCreX processes,
- return results or errors,
- surface the current PLCreX command catalog by inspecting the CLI help output.

### Non-responsibilities
The backend must not become:
- a workflow engine,
- a persistent job system,
- a multi-tenant stateful service,
- a platform abstraction layer over PLCreX.

### Process handling
PLCreX is started as a local process from the backend.

Suggested implementation approach:
- use Python subprocess handling,
- use temporary working directories,
- capture stdout/stderr,
- return error output on failure,
- clean up temporary files after request completion,
- provide helpers that run `plcrex --help` (or equivalent) and parse the output into a command catalog exposed through the API.

### API style
Keep the API minimal, but expose a dynamic command catalog derived from the PLCreX CLI help output so the frontend can stay in sync with new releases.

Required endpoints:
- `GET /api/commands` — run `plcrex --help` (or similar) and return a parsed command/argument description.
- `POST /api/run` — upload file and start execution using the parameters provided by the user via the command catalog.
- `GET /api/health` — health check.

Optional small additions are acceptable if needed for clean implementation, but the API should remain minimal beyond the endpoints listed above.

### Result handling
The first implementation should prefer simple request/response behavior.

That means:
- request starts PLCreX,
- backend waits,
- response returns output or error.

Do not introduce asynchronous job APIs unless they become necessary later.

---

## 10. Packaging and Build Architecture

This section belongs strictly to **Part A: Initialization and Packaging**.

### Required build inputs
The packaging step combines:
- current web project source,
- locally pulled `vendor/PLCreX/` checkout,
- Docker build instructions.

### Packaging result
The packaging flow must produce:
- final Docker image,
- SBOM file.

### Packaging entrypoint
A shell script performs packaging.

This script must:
1. verify that `vendor/PLCreX/` exists,
2. build the frontend,
3. prepare the backend runtime contents,
4. build the Docker image,
5. generate SBOM for the produced image.

### Command trigger
The packaging script must be callable via a `just` command.

Example command naming:
- `just pull-plcrex`
- `just package`

These names are good defaults and should be used unless there is a strong reason to change them.

---

## 11. Command Model

All important developer actions should be available through file-based commands.

### Required command entrypoint
- **Justfile**

### Required commands
At minimum, provide commands equivalent to:

```make
just pull-plcrex
just package
```

### Command responsibilities
#### `just pull-plcrex`
- clone PLCreX into `vendor/PLCreX/` if missing,
- otherwise refresh the local checkout to the newest upstream state.

#### `just package`
- call the shell packaging script,
- build frontend,
- build runtime Docker image,
- generate SBOM.

Optional helper commands may be added later, but the initial repo should stay minimal.

---

## 12. Folder Structure

The exact implementation may vary slightly, but the repository should follow this shape:

```text
project-root/
├─ backend/
│  ├─ app/
│  │  ├─ main.py
│  │  ├─ routes/
│  │  ├─ services/
│  │  └─ templates_or_static_mount_helpers/
│  ├─ pyproject.toml
│  └─ requirements or lock files
├─ frontend/
│  ├─ src/
│  ├─ public/
│  ├─ package.json
│  └─ vite.config.*
├─ scripts/
│  └─ package.sh
├─ vendor/
│  └─ PLCreX/          # gitignored, pulled locally only
├─ Dockerfile
├─ Justfile
├─ .gitignore
└─ architecture.md
```

### Notes
- `vendor/PLCreX/` must exist in path design but remain gitignored.
- The frontend build output should not be committed unless there is a deliberate deployment reason.
- The backend should serve the built frontend assets in the final runtime container.

---

## 13. Git Ignore Requirements

The `.gitignore` must include at least:

```gitignore
vendor/PLCreX/
node_modules/
frontend/dist/
__pycache__/
*.pyc
.env
*.sbom
*.spdx.json
```

Additional local build and IDE artifacts may be added as needed.

---

## 14. Docker Strategy

### Runtime strategy
Use a single Docker image for runtime.

The final image should contain:
- FastAPI backend
- built frontend assets
- PLCreX checkout or required PLCreX runtime files

### Serving strategy
FastAPI serves:
- API endpoints
- frontend static files

### Goal
Keep deployment simple:
- one image,
- one process entrypoint,
- no separate frontend container.

---

## 15. Error Handling Principles

The application should keep error handling understandable and visible.

### Frontend behavior
On failure, the UI should show error output returned from the backend.

### Backend behavior
When PLCreX fails:
- capture stdout/stderr,
- return a structured error response,
- do not hide the failure behind generic messages unless required for safety.

### Avoid
- silent failures
- background retries
- hidden retry loops

---

## 16. Security and Safety Baseline

Keep the first version simple, but not careless.

### Required baseline measures
- validate uploaded files at a basic level,
- use temporary working directories,
- avoid reusing state between requests,
- avoid executing arbitrary shell concatenations,
- call PLCreX through controlled subprocess invocation,
- do not trust browser history as backend truth.

### Optional future hardening
These are not required for initial setup but may be added later:
- file size limits,
- request limits,
- stricter content validation,
- container hardening.

---

## 17. Initialization Guidance for Codex

This section is intentionally explicit so a local coding agent can initialize the repo correctly.

### Initialization order
1. Create repo skeleton for frontend, backend, scripts, and root config files.
2. Configure `.gitignore` so `vendor/PLCreX/` is excluded.
3. Create `Justfile`.
4. Implement `just pull-plcrex`.
5. Create shell packaging script.
6. Set up React + TypeScript + Vite + Tailwind frontend.
7. Set up Python + FastAPI backend.
8. Make FastAPI serve frontend assets.
9. Implement minimal `/api/run` path that spawns PLCreX.
10. Implement browser-side history using `sessionStorage`.
11. Ensure `just package` builds image and generates SBOM.

### Important restriction
Do not start by embedding PLCreX source into the repo.

Do not design around persistent storage.

Do not introduce extra infrastructure before the minimal path works.

---

## 18. Non-Goals

The following are explicitly out of scope for the initial architecture:
- database-backed job history
- user authentication
- multi-user coordination
- real-time streaming logs
- distributed job execution
- microservices
- multi-container production split for frontend/backend
- custom plugin system around PLCreX

---

## 19. Summary

This project is a **minimal single-container web interface for PLCreX**.

The architecture is based on two strictly separated domains:

### A. Initialization / Packaging
- pull newest PLCreX into `vendor/PLCreX/`
- build frontend
- package Docker image
- generate SBOM
- all triggered through `just` commands and shell scripts

### B. Runtime Application
- FastAPI serves frontend and API
- React UI provides upload/run flow and session-bound history
- backend spawns PLCreX processes directly
- no database, no streaming, no persistent backend state

This separation must remain visible in repo structure and implementation decisions.
