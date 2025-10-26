from pydantic import BaseModel, Field

class SosInitRequest(BaseModel):
    """
    Schema for the encrypted SOS session initiation request.
    Validates the structure of the payload sent by the Flutter app.
    """
    creator_device_id: str = Field(..., description="Unique ID of the originating device.")
    encrypted_session_blob: str = Field(..., description="Base64 encoded ciphertext of the session metadata.")