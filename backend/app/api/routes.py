"""API routes powering the PLCreX web interface."""

from fastapi import APIRouter, Query

from ..models.plcrex import PlcrexCommand
from ..services.plcrex_commands import get_plcrex_commands

router = APIRouter(prefix="/api", tags=["plcrex"])


@router.get("/commands", response_model=list[PlcrexCommand], summary="List available PLCreX commands")
async def list_commands(refresh: bool = Query(False, description="Force refresh from PLCreX CLI help output")) -> list[PlcrexCommand]:
    """Return the PLCreX commands discovered via `plcrex --help`."""

    return get_plcrex_commands(force_refresh=refresh)


@router.get("/status", summary="Placeholder PLCreX status endpoint")
async def read_status() -> dict[str, str]:
    """Return a stub payload until the PLCreX runtime is wired in."""
    return {"plcrex": "runtime wiring pending"}
