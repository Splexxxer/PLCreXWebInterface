"""Domain models shared across PLCreX-specific endpoints."""

from __future__ import annotations

from pydantic import BaseModel, Field


class PlcrexCommand(BaseModel):
    """Representation of a PLCreX CLI command extracted from the help output."""

    name: str
    summary: str
    io: str | None = None
    accepts_upload: bool = True
    accepted_extensions: list[str] = Field(default_factory=list)
    output_extensions: list[str] = Field(default_factory=list)
    extra_path_label: str | None = None
    extra_path_placeholder: str | None = None
    unsupported_reason: str | None = None
    options: list["PlcrexOption"] = Field(default_factory=list)


class PlcrexOption(BaseModel):
    """Boolean command option exposed to the frontend."""

    name: str
    label: str
    description: str
    default: bool = False


class PlcrexRunOutput(BaseModel):
    """Generated output returned from a PLCreX execution."""

    filename: str
    content: str


class PlcrexRunRequestOption(BaseModel):
    """Single command option value posted from the frontend."""

    name: str
    value: bool


class PlcrexRunResponse(BaseModel):
    """Structured PLCreX execution response."""

    command: str
    filename: str | None = None
    status: str
    stdout: str = ""
    stderr: str = ""
    outputs: list[PlcrexRunOutput] = Field(default_factory=list)
