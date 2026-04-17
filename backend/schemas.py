from pydantic import BaseModel, Field
from typing import Optional


class RegisterRequest(BaseModel):
    username:  str = Field(..., min_length=2, max_length=50)
    device_id: str = Field(..., min_length=1)
    phone:     Optional[str] = None


class SosRequest(BaseModel):
    device_id:    str
    sos_type:     str = "manual"
    latitude:     float = 0.0
    longitude:    float = 0.0
    battery:      Optional[int] = None
    t0_client_ms: Optional[int] = None


class ContactCreate(BaseModel):
    device_id:    str
    name:         str = Field(..., min_length=1, max_length=100)
    phone:        str = Field(..., min_length=3)
    relationship: Optional[str] = None
