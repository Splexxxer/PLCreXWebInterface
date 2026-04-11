"""API routes powering the PLCreX web interface."""

from typing import List, Optional

from fastapi import APIRouter, File, Form, Query, UploadFile

from ..models.plcrex import PlcrexCommand, PlcrexRunResponse
from ..services.plcrex_commands import get_plcrex_commands, run_plcrex_command

router = APIRouter(prefix="/api", tags=["plcrex"])


@router.get("/commands", response_model=List[PlcrexCommand], summary="List available PLCreX commands")
async def list_commands(refresh: bool = Query(False, description="Force refresh from PLCreX CLI help output")) -> List[PlcrexCommand]:
    """Return the PLCreX commands discovered via `plcrex --help`."""

    return get_plcrex_commands(force_refresh=refresh)


@router.post("/run", response_model=PlcrexRunResponse, summary="Run PLCreX against an uploaded file")
async def run_command(
    command: str = Form(...),
    file: Optional[UploadFile] = File(None),
    input_text: Optional[str] = Form(None),
    options: Optional[str] = Form(None),
    extra_path: Optional[str] = Form(None),
) -> PlcrexRunResponse:
    """Execute a PLCreX command for the uploaded file."""

    return await run_plcrex_command(
        command_name=command,
        upload=file,
        input_text=input_text,
        raw_options=options,
        extra_path=extra_path,
    )


@router.get("/health", summary="PLCreX API health endpoint")
async def read_health() -> dict[str, str]:
    """Return API health status."""

    return {"status": "ok"}
