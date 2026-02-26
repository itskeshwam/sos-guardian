from fastapi import FastAPI, status, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any
import uvicorn
import uuid
import base64
import json

import schemas
import models
import database

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="AI SOS Guardian Backend")

@app.get("/")
def read_root():
    return {"service": "AI SOS Guardian", "status": "active_persistence"}

@app.post("/v1/register", status_code=status.HTTP_201_CREATED)
async def register_user(
        request: schemas.UserRegistrationRequest,
        db: Session = Depends(database.get_db),
) -> Dict[str, Any]:

    existing_user = (
        db.query(models.User.id)
        .filter(models.User.username == request.username)
        .first()
    )
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail=f"Username '{request.username}' is already taken.",
        )

    new_user = models.User(
        username=request.username,
        device_id=request.device_id,
        identity_key_pub=request.identity_key_pub,
    )

    try:
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database persistence error.")

    return {
        "status": "success",
        "user_id": new_user.id,
        "message": "User identity secured.",
    }

@app.post("/v1/sos/init", status_code=status.HTTP_201_CREATED)
async def post_sos_init(
        request: schemas.SosInitRequest,
        db: Session = Depends(database.get_db),
) -> Dict[str, Any]:

    session_id = f"SOS-{uuid.uuid4().hex[:8]}"

    try:
        decoded_bytes = base64.b64decode(request.encrypted_session_blob)
        payload = json.loads(decoded_bytes.decode("utf-8"))
        print(f"\n🚨 [EMERGENCY ALERT] - Session: {session_id}")
        print(f"Device: {request.creator_device_id}")
        print(f"Location: {payload.get('lat')}, {payload.get('lon')}")
        print(f"Message: {payload.get('message')}")
        print(f"Time: {payload.get('timestamp')}")
    except Exception as e:
        print(f"Critical: Failed to decode incoming JSON payload. Error: {e}")

    new_signal = models.SosSignal(
        session_id=session_id,
        creator_device_id=request.creator_device_id,
        encrypted_blob=request.encrypted_session_blob,
    )

    db.add(new_signal)
    db.commit()

    return {"session_id": session_id, "status": "success"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)