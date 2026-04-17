import os
import time
import asyncio
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from dotenv import load_dotenv
import uvicorn

import models
import schemas
import database

load_dotenv()
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="SOS Guardian API", version="3.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)


def now_ms() -> int:
    return int(time.time() * 1000)


def build_message(
    sos_type: str,
    username: str,
    lat: float,
    lon: float,
    battery: Optional[int],
) -> str:
    ts = datetime.now(timezone.utc).strftime("%d %b %Y %H:%M:%S UTC")
    maps_link = f"https://maps.google.com/?q={lat:.6f},{lon:.6f}"

    headlines = {
        "manual":   "🆘 MANUAL SOS ACTIVATED",
        "crash":    "🚗 CRASH DETECTED — AUTO SOS SENT",
        "guardian": "⏰ GUARDIAN AUTO-SOS — NO CHECK-IN RECEIVED",
        "fall":     "🏔️ FALL DETECTED — AUTO SOS SENT",
    }
    headline = headlines.get(sos_type, "🆘 SOS ALERT")
    bat_line = f"\nBattery: {battery}%" if battery is not None else ""

    return (
        f"{headline}\n\n"
        f"User     : {username}\n"
        f"Time     : {ts}\n"
        f"Location : {lat:.6f}, {lon:.6f}\n"
        f"Maps     : {maps_link}"
        f"{bat_line}\n\n"
        f"— Sent via SOS Guardian App"
    )


# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"status": "ok", "service": "SOS Guardian", "version": "3.0.0"}


# ── Register ──────────────────────────────────────────────────────────────────

@app.post("/v1/register", status_code=status.HTTP_201_CREATED)
def register(req: schemas.RegisterRequest, db: Session = Depends(database.get_db)):
    existing = db.query(models.User).filter(
        models.User.device_id == req.device_id
    ).first()
    if existing:
        # Update username if changed
        if existing.username != req.username:
            existing.username = req.username
            db.commit()
        return {"user_id": existing.id, "status": "exists", "username": existing.username}

    user = models.User(
        username=req.username,
        device_id=req.device_id,
        phone=req.phone,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    print(f"[REGISTER] New user: {user.username} ({user.device_id[:8]}…)")
    return {"user_id": user.id, "status": "created", "username": user.username}


# ── SOS ───────────────────────────────────────────────────────────────────────

@app.post("/v1/sos", status_code=status.HTTP_201_CREATED)
def send_sos(req: schemas.SosRequest, db: Session = Depends(database.get_db)):
    t1 = now_ms()

    user = db.query(models.User).filter(
        models.User.device_id == req.device_id
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="Device not registered. Please register first.")

    message = build_message(req.sos_type, user.username, req.latitude, req.longitude, req.battery)

    event = models.SosEvent(
        device_id    = req.device_id,
        sos_type     = req.sos_type,
        latitude     = req.latitude,
        longitude    = req.longitude,
        battery      = req.battery,
        message      = message,
        t0_client_ms = req.t0_client_ms,
        t1_server_ms = t1,
    )
    db.add(event)
    db.commit()

    t2 = now_ms()
    event.t2_db_ms = t2
    db.commit()
    db.refresh(event)

    net_ms  = (t1 - req.t0_client_ms)        if req.t0_client_ms else None
    proc_ms = t2 - t1
    e2e_ms  = (t2 - req.t0_client_ms)        if req.t0_client_ms else None
    payload_bytes = len(message.encode("utf-8"))

    print(
        f"[{req.sos_type.upper()}] {event.session_id} | {user.username} | "
        f"{req.latitude:.4f},{req.longitude:.4f} | "
        f"Net={net_ms}ms Proc={proc_ms}ms E2E={e2e_ms}ms | {payload_bytes}B"
    )

    return {
        "session_id": event.session_id,
        "status":     "sent",
        "sos_type":   req.sos_type,
        "message":    message,
        "latency": {
            "t0_ms":          req.t0_client_ms,
            "t1_ms":          t1,
            "t2_ms":          t2,
            "network_ms":     net_ms,
            "processing_ms":  proc_ms,
            "e2e_ms":         e2e_ms,
            "payload_bytes":  payload_bytes,
        },
    }


@app.patch("/v1/sos/{session_id}/resolve", status_code=status.HTTP_200_OK)
def resolve_sos(session_id: str, db: Session = Depends(database.get_db)):
    event = db.query(models.SosEvent).filter(
        models.SosEvent.session_id == session_id
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Session not found")
    event.status = "resolved"
    db.commit()
    return {"session_id": session_id, "status": "resolved"}


# ── Contacts ──────────────────────────────────────────────────────────────────

@app.post("/v1/contacts", status_code=status.HTTP_201_CREATED)
def add_contact(req: schemas.ContactCreate, db: Session = Depends(database.get_db)):
    dup = db.query(models.Contact).filter(
        models.Contact.device_id == req.device_id,
        models.Contact.phone == req.phone,
    ).first()
    if dup:
        raise HTTPException(status_code=409, detail="Contact with this number already exists")

    c = models.Contact(
        device_id=req.device_id,
        name=req.name,
        phone=req.phone,
        relationship=req.relationship,
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    return {"id": c.id, "name": c.name, "phone": c.phone, "relationship": c.relationship}


@app.get("/v1/contacts/{device_id}")
def list_contacts(device_id: str, db: Session = Depends(database.get_db)):
    contacts = db.query(models.Contact).filter(
        models.Contact.device_id == device_id
    ).order_by(models.Contact.created_at).all()
    return [
        {"id": c.id, "name": c.name, "phone": c.phone, "relationship": c.relationship}
        for c in contacts
    ]


@app.delete("/v1/contacts/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(contact_id: str, db: Session = Depends(database.get_db)):
    c = db.query(models.Contact).filter(models.Contact.id == contact_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="Contact not found")
    db.delete(c)
    db.commit()


# ── History ───────────────────────────────────────────────────────────────────

@app.get("/v1/history/{device_id}")
def get_history(device_id: str, db: Session = Depends(database.get_db)):
    events = (
        db.query(models.SosEvent)
        .filter(models.SosEvent.device_id == device_id)
        .order_by(models.SosEvent.created_at.desc())
        .limit(50)
        .all()
    )
    return [
        {
            "session_id": e.session_id,
            "sos_type":   e.sos_type,
            "status":     e.status,
            "latitude":   e.latitude,
            "longitude":  e.longitude,
            "battery":    e.battery,
            "message":    e.message,
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "net_ms":     (e.t1_server_ms - e.t0_client_ms) if (e.t1_server_ms and e.t0_client_ms) else None,
            "e2e_ms":     (e.t2_db_ms - e.t0_client_ms) if (e.t2_db_ms and e.t0_client_ms) else None,
        }
        for e in events
    ]


# ── Latency ───────────────────────────────────────────────────────────────────

@app.get("/v1/latency/{device_id}")
def latency_report(device_id: str, db: Session = Depends(database.get_db)):
    events = (
        db.query(models.SosEvent)
        .filter(
            models.SosEvent.device_id == device_id,
            models.SosEvent.t0_client_ms.isnot(None),
            models.SosEvent.t2_db_ms.isnot(None),
        )
        .order_by(models.SosEvent.created_at.desc())
        .limit(20)
        .all()
    )
    if not events:
        return {"count": 0, "message": "No latency data yet. Send at least one SOS."}

    net  = [e.t1_server_ms - e.t0_client_ms for e in events if e.t1_server_ms]
    proc = [e.t2_db_ms - e.t1_server_ms     for e in events if e.t1_server_ms]
    e2e  = [e.t2_db_ms - e.t0_client_ms     for e in events]

    def stats(vals):
        if not vals:
            return {}
        return {
            "avg_ms": round(sum(vals) / len(vals), 1),
            "min_ms": min(vals),
            "max_ms": max(vals),
        }

    return {
        "count":      len(events),
        "network":    stats(net),
        "processing": stats(proc),
        "e2e":        stats(e2e),
    }


# ── Stress test ───────────────────────────────────────────────────────────────

@app.get("/v1/stress")
async def stress_test(n: int = 100):
    start = now_ms()

    async def fake_req():
        t1 = now_ms()
        await asyncio.sleep(0.001)
        return now_ms() - t1

    results = await asyncio.gather(*[fake_req() for _ in range(n)])
    elapsed = now_ms() - start

    return {
        "requests":     n,
        "total_ms":     elapsed,
        "avg_proc_ms":  round(sum(results) / len(results), 2),
        "throughput_rps": round(n / (elapsed / 1000), 1),
        "note": f"FastAPI handled {n} concurrent tasks in {elapsed}ms",
    }


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", 8000)),
        reload=True,
    )
