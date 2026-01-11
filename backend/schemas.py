from pydantic import BaseModel, Field

class SosInitRequest(BaseModel):
    """Validated schema for SOS initiation."""
    creator_device_id: str = Field(..., description="Unique ID of the originating device.")
    encrypted_session_blob: str = Field(..., description="Base64 encoded ciphertext of the session metadata.")

class UserRegistrationRequest(BaseModel):
    """Validated schema for user registration and key exchange."""
    username: str = Field(..., min_length=3, max_length=50, description="Unique user-chosen handle.")
    device_id: str = Field(..., description="Unique device identifier.")
    identity_key_pub: str = Field(..., description="Base64URL-encoded X25519 Public Identity Key.")