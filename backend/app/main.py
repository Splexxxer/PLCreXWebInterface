"""Application entrypoint for the PLCreX web backend."""

from __future__ import annotations

from fastapi import FastAPI

from .api import router as api_router
from .frontend import mount_frontend


def create_app() -> FastAPI:
    """Build and configure the FastAPI application."""

    app = FastAPI(title="PLCreX Web Interface", version="0.1.0")

    register_routes(app)
    mount_frontend(app)

    return app


def register_routes(app: FastAPI) -> None:
    """Register core routes and routers."""

    @app.get("/health", tags=["system"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(api_router)


app = create_app()
