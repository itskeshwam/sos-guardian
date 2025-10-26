# ----------------------------------------------------
# File: backend/main.py
# Action: Confirm this exact code is in your file.
# ----------------------------------------------------
from fastapi import FastAPI, status
from typing import Dict, Any
import uvicorn
import time
# FIX: Direct import resolves "ImportError: attempted relative import" when running Uvicorn.
import schemas 

# Initialize the FastAPI app
app = FastAPI(
    title="AI SOS Guardian Backend MVP",
    description="Minimal Orchestrator for SOS initiation.",
)

# --- Endpoints ---

@app.get("/")
def read_root():
    return {"service": "AI SOS Guardian Orchestrator", "status": "online", "version": "MVP 1.0"}

@app.post("/v1/sos/init", status_code=status.HTTP_201_CREATED)
async def post_sos_init(request_data: schemas.SosInitRequest) -> Dict[str, Any]:
    """
    MVP Endpoint: Receives the encrypted SOS initiation request.
    This simulates the core task of the server successfully logging the event.
    """
    session_id = f"SOS-{request_data.creator_device_id}-{int(time.time())}"
    
    # --- SIMULATING BACKEND ACTIONS ---
    # Log the successful event (The most important part for testing the mobile app)
    print(f"\n--- API SUCCESS (201) ---")
    print(f"Session ID: {session_id}")
    print(f"Device ID: {request_data.creator_device_id}")
    print(f"Encrypted Payload Received: {request_data.encrypted_session_blob[:50]}...")
    print(f"Action: Notifications (Push/SMS) triggered successfully.")
    print(f"--------------------------\n")

    # Simulate network latency
    await time.sleep(0.05) 
    
    return {
        "session_id": session_id,
        "status": "success",
        "message": "SOS event logged. Notifications triggered."
    }

# This section runs the server when executing the file directly.
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)