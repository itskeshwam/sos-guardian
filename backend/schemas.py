# ----------------------------------------------------
# File: backend/schemas.py
# Action: Replace the entire file content with both schemas.
# ----------------------------------------------------
from pydantic import BaseModel, Field

class SosInitRequest(BaseModel):
    """Schema for the SOS initiation request."""
    creator_device_id: str = Field(..., description="Unique ID of the originating device.")
    encrypted_session_blob: str = Field(..., description="Base64 encoded ciphertext of the session metadata.")

class UserRegistrationRequest(BaseModel):
    """
    Schema for initial user registration and key exchange.
    The public key is required to establish the user's identity on this device.
    """
    username: str = Field(..., description="Unique user-chosen handle.")
    device_id: str = Field(..., description="Unique device identifier (UUID or similar).")
    identity_key_pub: str = Field(..., description="Base64URL-encoded X25519 Public Identity Key.")