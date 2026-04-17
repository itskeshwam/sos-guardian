import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, Integer, BigInteger, Text, DateTime

from database import Base


def _uuid():
    return str(uuid.uuid4())


def _now():
    return datetime.now(timezone.utc)


def _session_id():
    return "SOS-" + uuid.uuid4().hex[:10].upper()


class User(Base):
    __tablename__ = "users"
    id         = Column(String, primary_key=True, default=_uuid)
    username   = Column(String(50), unique=True, nullable=False)
    device_id  = Column(String, unique=True, nullable=False, index=True)
    phone      = Column(String(20), nullable=True)
    created_at = Column(DateTime(timezone=True), default=_now)


class Contact(Base):
    __tablename__ = "contacts"
    id           = Column(String, primary_key=True, default=_uuid)
    device_id    = Column(String, nullable=False, index=True)
    name         = Column(String(100), nullable=False)
    phone        = Column(String(30), nullable=False)
    relationship = Column(String(50), nullable=True)
    created_at   = Column(DateTime(timezone=True), default=_now)


class SosEvent(Base):
    __tablename__ = "sos_events"
    id            = Column(String, primary_key=True, default=_uuid)
    session_id    = Column(String, unique=True, nullable=False, default=_session_id)
    device_id     = Column(String, nullable=False, index=True)
    sos_type      = Column(String(30), default="manual")
    status        = Column(String(20), default="active")
    latitude      = Column(Float, nullable=True)
    longitude     = Column(Float, nullable=True)
    battery       = Column(Integer, nullable=True)
    message       = Column(Text, nullable=True)
    t0_client_ms  = Column(BigInteger, nullable=True)
    t1_server_ms  = Column(BigInteger, nullable=True)
    t2_db_ms      = Column(BigInteger, nullable=True)
    created_at    = Column(DateTime(timezone=True), default=_now)
