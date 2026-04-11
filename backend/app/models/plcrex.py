"""Domain models shared across PLCreX-specific endpoints."""

from typing import List, Optional

from pydantic import BaseModel, Field


class PlcrexCommand(BaseModel):
    """Representation of a PLCreX CLI command extracted from the help output."""

    name: str
    summary: str
    io: Optional[str] = None
    accepts_upload: bool = True
    accepts_text_input: bool = False
    accepted_extensions: List[str] = Field(default_factory=list)
    output_extensions: List[str] = Field(default_factory=list)
    extra_path_label: Optional[str] = None
    extra_path_placeholder: Optional[str] = None
    text_input_label: Optional[str] = None
    text_input_placeholder: Optional[str] = None
    unsupported_reason: Optional[str] = None
    options: List["PlcrexOption"] = Field(default_factory=list)


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
    filename: Optional[str] = None
    status: str
    stdout: str = ""
    stderr: str = ""
    outputs: List[PlcrexRunOutput] = Field(default_factory=list)
