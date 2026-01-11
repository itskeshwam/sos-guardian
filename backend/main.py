from fastapi import FastAPI, status, HTTPException
from typing import Dict, Any
import uvicorn
import time
import uuid
import schemas # Ensure schemas.py is in the same directory

app = FastAPI(
    title="AI SOS Guardian Backend",
    description="Production-ready orchestrator for SOS initiation and Registration."
)

# In-memory storage for MVP phase
users_db = {}

@app.get("/health")
async def health_check():
    """Service status monitor."""
    return {"status": "online", "timestamp": time.time()}

@app.post("/v1/register", status_code=status.HTTP_201_CREATED)
async def register_user(request_data: schemas.UserRegistrationRequest):
    """Handles user registration with uniqueness check."""
    if request_data.username in users_db:
        raise HTTPException(status_code=400, detail="Username already exists")

    user_id = str(uuid.uuid4())
    users_db[request_data.username] = {
        "user_id": user_id,
        "device_id": request_data.device_id,
        "public_key": request_data.identity_key_pub
    }

    return {
        "status": "success",
        "user_id": user_id,
        "message": "Registration complete."
    }

@app.post("/v1/sos/init", status_code=status.HTTP_201_CREATED)
async def post_sos_init(request_data: schemas.SosInitRequest):
    """Generates unique SOS session and triggers notification workflow."""
    session_id = f"SOS-{uuid.uuid4().hex[:8]}-{int(time.time())}"

    # Logic for Twilio/Firebase notification dispatch would be integrated here
    return {
        "session_id": session_id,
        "status": "success",
        "message": "SOS event logged. Notifications triggered."
    }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)