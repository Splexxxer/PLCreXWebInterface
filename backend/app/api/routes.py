"""Placeholder API routes for future PLCreX integrations."""

from fastapi import APIRouter

router = APIRouter(prefix="/api", tags=["plcrex"])


@router.get("/status", summary="Placeholder PLCreX status endpoint")
async def read_status() -> dict[str, str]:
    """Return a stub payload until the PLCreX runtime is wired in."""
    return {"plcrex": "runtime wiring pending"}
