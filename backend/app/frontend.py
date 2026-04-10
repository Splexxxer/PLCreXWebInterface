"""Helpers for serving the built frontend bundle."""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles

DEFAULT_DIST_PATH = Path(__file__).resolve().parents[2] / "frontend" / "dist"


def mount_frontend(app: FastAPI, dist_path: Path | None = None) -> None:
    """Wire the built frontend (if available) into the FastAPI application."""

    target = dist_path or DEFAULT_DIST_PATH
    assets_dir = target / "assets"

    if assets_dir.exists():
        app.mount("/assets", StaticFiles(directory=assets_dir), name="frontend-assets")

    index_file = target / "index.html"

    if index_file.exists():
        @app.get("/", include_in_schema=False)
        async def serve_index() -> FileResponse:  # pragma: no cover - thin wrapper
            return FileResponse(index_file)
    else:
        @app.get("/", include_in_schema=False)
        async def frontend_placeholder() -> Response:
            message = (
                "Frontend build artifacts not found. Run `npm run build` inside frontend/ "
                "and redeploy the backend to serve the compiled bundle."
            )
            return JSONResponse({"detail": message})
