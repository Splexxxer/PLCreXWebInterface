set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default_python := "/Users/mazzel/miniconda3/envs/plcrexwebinterface/bin/python"
default_npm := "npm"
default_uvicorn_host := "0.0.0.0"
default_uvicorn_port := "8000"

default:
    @just --list

pull-plcrex:
    ./scripts/pull_plcrex.sh

frontend-dev:
    cd frontend && ${NPM:-{{default_npm}}} run dev -- --host

frontend-build:
    cd frontend && ${NPM:-{{default_npm}}} run build

backend-dev:
    cd backend && ${PYTHON:-{{default_python}}} -m uvicorn app.main:app --reload --host ${UVICORN_HOST:-{{default_uvicorn_host}}} --port ${UVICORN_PORT:-{{default_uvicorn_port}}}

package:
    ./scripts/package_app.sh

dev-up:
    trap 'pids=$(jobs -p); if [ -n "$pids" ]; then kill $pids; fi' EXIT
    (cd frontend && ${NPM:-{{default_npm}}} run dev -- --host) &
    (cd backend && ${PYTHON:-{{default_python}}} -m uvicorn app.main:app --reload --host ${UVICORN_HOST:-{{default_uvicorn_host}}} --port ${UVICORN_PORT:-{{default_uvicorn_port}}}) &
    wait

dev-up-build:
    just frontend-build
    just dev-up

docker-build:
    ./scripts/pull_plcrex.sh
    docker build -t plcrex-web .

docker-run:
    docker run --rm -p 8000:8000 plcrex-web
