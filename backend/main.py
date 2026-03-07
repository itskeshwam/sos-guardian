import os
import uuid
import base64
import json
from fastapi import FastAPI, status, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any
from cryptography.hazmat.primitives.asymmetric import x25519
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

import schemas
import models
import database

models.Base.metadata.create_all(bind=database.engine)

KEY_FILE = "server_x25519.key"
if os.path.exists(KEY_FILE):
    with open(KEY_FILE, "rb") as f:
        SERVER_PRIVATE_KEY = x25519.X25519PrivateKey.from_private_bytes(f.read())
else:
    SERVER_PRIVATE_KEY = x25519.X25519PrivateKey.generate()
    with open(KEY_FILE, "wb") as f:
        f.write(SERVER_PRIVATE_KEY.private_bytes_raw())

SERVER_PUBLIC_KEY = SERVER_PRIVATE_KEY.public_key()
SERVER_PUB_B64 = base64.urlsafe_b64encode(SERVER_PUBLIC_KEY.public_bytes_raw()).decode('utf-8')

app = FastAPI(title="AI SOS Guardian Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"service": "AI SOS Guardian", "status": "active_persistence"}

@app.get("/v1/server-key")
def get_server_key():
    return {"server_key_pub": SERVER_PUB_B64}

@app.post("/v1/register", status_code=status.HTTP_201_CREATED)
async def register_user(
        request: schemas.UserRegistrationRequest,
        db: Session = Depends(database.get_db),
) -> Dict[str, Any]:

    existing_user = db.query(models.User.id).filter(models.User.username == request.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail=f"Username '{request.username}' is already taken.")

    new_user = models.User(
        username=request.username,
        device_id=request.device_id,
        identity_key_pub=request.identity_key_pub,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {"status": "success", "user_id": new_user.id}

@app.post("/v1/sos/init", status_code=status.HTTP_201_CREATED)
async def post_sos_init(
        request: schemas.SosInitRequest,
        db: Session = Depends(database.get_db),
) -> Dict[str, Any]:

    session_id = f"SOS-{uuid.uuid4().hex[:8]}"

    # FIX: Order by descending ID/Time to guarantee we get the latest key if collisions occur
    user = db.query(models.User).filter(models.User.device_id == request.creator_device_id).order_by(models.User.id.desc()).first()

    if not user:
        raise HTTPException(status_code=404, detail="Unregistered device")

    print(f"\n[VERIFICATION] Raw Encrypted Payload Received: {request.encrypted_session_blob[:60]}...")

    try:
        pub_key_str = user.identity_key_pub
        pub_key_padded = pub_key_str + '=' * (-len(pub_key_str) % 4)
        user_pub_bytes = base64.urlsafe_b64decode(pub_key_padded)

        user_pub_key = x25519.X25519PublicKey.from_public_bytes(user_pub_bytes)
        shared_secret = SERVER_PRIVATE_KEY.exchange(user_pub_key)

        blob_padded = request.encrypted_session_blob + '=' * (-len(request.encrypted_session_blob) % 4)
        encrypted_data = base64.urlsafe_b64decode(blob_padded)

        nonce = encrypted_data[:12]
        ciphertext_with_mac = encrypted_data[12:]

        chacha = ChaCha20Poly1305(shared_secret)
        decrypted_bytes = chacha.decrypt(nonce, ciphertext_with_mac, None)
        payload = json.loads(decrypted_bytes.decode("utf-8"))

        print(f"\n🚨 [EMERGENCY ALERT] - Session: {session_id}")
        print(f"Device: {request.creator_device_id} ({user.username})")
        print(f"Location: {payload.get('lat')}, {payload.get('lon')}")
        print(f"Message: {payload.get('message')}")
        print(f"Time: {payload.get('timestamp')}")
    except Exception as e:
        # FIX: Expose the actual cryptography stack trace to the terminal
        print(f"Decryption Error: {repr(e)}")
        raise HTTPException(status_code=400, detail="Decryption failed. Invalid payload.")

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