"""Domain models shared across PLCreX-specific endpoints."""

from __future__ import annotations

from pydantic import BaseModel


class PlcrexCommand(BaseModel):
    """Representation of a PLCreX CLI command extracted from the help output."""

    name: str
    summary: str
    io: str | None = None
