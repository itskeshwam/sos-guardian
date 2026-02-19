# backend/main.py
from fastapi import FastAPI, status, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any
import uvicorn
import uuid

from sqlalchemy.sql.functions import session_user

import schemas
import models
import database
import base64

# This command creates the tables (users, sos_signals) in Postgres if they don't exist
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="AI SOS Guardian Backend")

@app.get("/")
def read_root():
    return {"service": "AI SOS Guardian", "status": "active_persistence"}

@app.post("/v1/register", status_code=status.HTTP_201_CREATED)
async def register_user(
        request: schemas.UserRegistrationRequest,
        db: Session = Depends(database.get_db)
) -> Dict[str, Any]:

    # 1. Check if username exists in DB
    existing_user = db.query(models.User).filter(models.User.username == request.username).first()
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail=f"Username '{request.username}' is already taken."
        )

    # 2. Save new user to DB
    new_user = models.User(
        username=request.username,
        device_id=request.device_id,
        identity_key_pub=request.identity_key_pub
    )

    try:
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

    return {
        "status": "success",
        "user_id": new_user.id,
        "message": "User identity secured in database."
    }

@app.post("/v1/sos/init", status_code=status.HTTP_201_CREATED)
async def post_sos_init(
        request: schemas.SosInitRequest,
        db: Session = Depends(database.get_db)
) -> Dict[str, Any]:

    session_id = f"SOS-{uuid.uuid4().hex[:8]}"

    # 1. Decrypt/Decode the payload for the Console (Proof of Life)
    try:
        # In MVP, this is Base64. In Phase 2, this will be AES-GCM decryption.
        decoded_bytes = base64.b64decode(request.encrypted_session_blob)
        decoded_str = decoded_bytes.decode('utf-8')
        print(f"\n🚨 [EMERGENCY ALERT] 🚨")
        print(f"Session ID: {session_id}")
        print(f"Device: {request.creator_device_id}")
        print(f"Payload: {decoded_str}") # <--- THIS IS THE MAGIC LINE
        print(f"Action: Dispatching Rescue Teams (Simulation)\n")
    except Exception as e:
        print(f"Error decoding payload: {e}")

    # 2. Persist to DB
    new_signal = models.SosSignal(
        session_id=session_id,
        creator_device_id=request.creator_device_id,
        encrypted_blob=request.encrypted_session_blob
    )

    db.add(new_signal)
    db.commit()

    return {
        "session_id": session_id,
        "status": "success",
        "message": "Critical Alert persisted."
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)