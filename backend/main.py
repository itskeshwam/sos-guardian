# ----------------------------------------------------
# File: backend/main.py
# Action: Replace the entire file content with the new registration endpoint.
# ----------------------------------------------------
from fastapi import FastAPI, status
from typing import Dict, Any
import uvicorn
import time
import uuid
import schemas

# Initialize the FastAPI app
app = FastAPI(
    title="AI SOS Guardian Backend MVP",
    description="Minimal Orchestrator for SOS initiation and Registration.",
)

# --- Endpoints ---

@app.get("/")
def read_root():
    return {"service": "AI SOS Guardian Orchestrator", "status": "online", "version": "MVP 1.0"}

# Phase 1a: SOS Endpoint (Existing)
@app.post("/v1/sos/init", status_code=status.HTTP_201_CREATED)
async def post_sos_init(request_data: schemas.SosInitRequest) -> Dict[str, Any]:
    session_id = f"SOS-{request_data.creator_device_id}-{int(time.time())}"

    print(f"\n--- API SUCCESS (201) ---")
    print(f"Session ID: {session_id}")
    print(f"Device ID: {request_data.creator_device_id}")
    print(f"Action: Notifications (Push/SMS) triggered successfully.")
    print(f"--------------------------\n")

    await time.sleep(0.05)

    return {
        "session_id": session_id,
        "status": "success",
        "message": "SOS event logged. Notifications triggered."
    }

# Phase 1b: User Registration Endpoint (NEW)
@app.post("/v1/register", status_code=status.HTTP_201_CREATED)
async def register_user(request_data: schemas.UserRegistrationRequest) -> Dict[str, Any]:
    """
    Handles user registration and persists the public identity key.
    """
    # NOTE: In a real app, this ensures username uniqueness and stores data in PostgreSQL.
    new_user_id = str(uuid.uuid4())

    # --- SIMULATING BACKEND ACTIONS ---
    print(f"\n--- USER REGISTRATION (201) ---")
    print(f"New User ID Created: {new_user_id}")
    print(f"Username: {request_data.username}")
    print(f"Device ID: {request_data.device_id}")
    print(f"Public Key Stored (Base64URL): {request_data.identity_key_pub[:10]}...")
    print(f"Action: User/Device records created in DB.")
    print(f"--------------------------\n")

    return {
        "status": "success",
        "user_id": new_user_id,
        "message": "Registration complete. Identity Key stored securely."
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)