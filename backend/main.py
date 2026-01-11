from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
import models, schemas, database
import time
import uuid

# Initialize DB tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="AI SOS Guardian Backend")

@app.get("/health")
def health_check():
    return {"status": "online"}

@app.post("/v1/register", status_code=status.HTTP_201_CREATED)
def register_user(request: schemas.UserRegistrationRequest, db: Session = Depends(database.get_db)):
    db_user = db.query(models.User).filter(models.User.username == request.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")

    new_user = models.User(
        username=request.username,
        device_id=request.device_id,
        identity_key_pub=request.identity_key_pub
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"status": "success", "user_id": new_user.user_id}

@app.post("/v1/sos/init", status_code=status.HTTP_201_CREATED)
def init_sos(request: schemas.SosInitRequest, db: Session = Depends(database.get_db)):
    session_id = f"SOS-{uuid.uuid4().hex[:8]}-{int(time.time())}"

    new_event = models.SosEvent(
        session_id=session_id,
        creator_device_id=request.creator_device_id,
        encrypted_blob=request.encrypted_session_blob
    )
    db.add(new_event)
    db.commit()

    # Placeholder for external alert service (Twilio/Firebase)
    return {"session_id": session_id, "status": "alerts_dispatched"}