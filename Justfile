set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default_python := "python3"
default_npm := "npm"
default_uvicorn_host := "0.0.0.0"
default_uvicorn_port := "8000"
default_docker_container_name := "plcrex-web-dev"
dev_pid_file := ".devserver-pids"

default:
	@just --list

pull-plcrex:
	./scripts/pull_plcrex.sh

install:
	${PYTHON:-{{default_python}}} -m pip install --upgrade pip setuptools wheel
	${PYTHON:-{{default_python}}} -m pip install -r backend/requirements.txt
	${PYTHON:-{{default_python}}} -m pip install --upgrade "typing_extensions>=4.14" "packaging>=24"
	(cd frontend && ${NPM:-{{default_npm}}} install)

frontend-dev:
	cd frontend && ${NPM:-{{default_npm}}} run dev -- --host

frontend-build:
	cd frontend && ${NPM:-{{default_npm}}} run build

backend-dev:
	cd backend && ${PYTHON:-{{default_python}}} -m uvicorn app.main:app --reload --host ${UVICORN_HOST:-{{default_uvicorn_host}}} --port ${UVICORN_PORT:-{{default_uvicorn_port}}}

package:
	./scripts/package_app.sh

dev-up:
	rm -f {{dev_pid_file}}; \
	trap 'pids=$(jobs -p); if [ -n "$pids" ]; then kill $pids; fi; rm -f {{dev_pid_file}}' EXIT; \
	: > {{dev_pid_file}}; \
	frontend_cmd() { cd frontend && exec ${NPM:-{{default_npm}}} run dev -- --host; }; \
	backend_cmd() { cd backend && exec ${PYTHON:-{{default_python}}} -m uvicorn app.main:app --reload --host ${UVICORN_HOST:-{{default_uvicorn_host}}} --port ${UVICORN_PORT:-{{default_uvicorn_port}}}; }; \
	frontend_cmd & frontend_pid=$!; \
	echo "$frontend_pid" >> {{dev_pid_file}}; \
	backend_cmd & backend_pid=$!; \
	echo "$backend_pid" >> {{dev_pid_file}}; \
	wait

dev-up-build:
	just frontend-build
	just dev-up

dev-down:
	{ \
	if [ ! -f {{dev_pid_file}} ]; then \
	    echo "No dev server PID file found (run 'just dev-up' first)."; \
	    exit 0; \
	fi; \
	while IFS= read -r pid; do \
	    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then \
	        kill "$pid" 2>/dev/null || true; \
	    fi; \
	done < {{dev_pid_file}}; \
	rm -f {{dev_pid_file}}; \
	echo "Dev servers stopped."; \
	}

docker-build:
	if [ ! -d vendor/PLCreX/.git ]; then ./scripts/pull_plcrex.sh; fi
	docker build -t plcrex-web .

docker-run:
	docker run --rm --name ${DOCKER_CONTAINER_NAME:-{{default_docker_container_name}}} -p 8000:8000 plcrex-web

docker-build-upgrade:
	./scripts/pull_plcrex.sh
	just docker-build

down:
	{ \
	container_name=${DOCKER_CONTAINER_NAME:-{{default_docker_container_name}}}; \
	container_id=$(docker ps -q --filter "name=${container_name}"); \
	if [ -z "$container_id" ]; then \
	    echo "No running container named $container_name"; \
	else \
	    docker stop "$container_id"; \
	fi; \
	}
