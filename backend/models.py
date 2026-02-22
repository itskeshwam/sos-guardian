from sqlalchemy import Column, String, DateTime, Text
from sqlalchemy.sql import func
from backend.database import Base
import uuid


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, index=True, nullable=False)
    device_id = Column(String, nullable=False)
    identity_key_pub = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class SosSignal(Base):
    __tablename__ = "sos_signals"

    session_id = Column(String, primary_key=True, index=True)
    creator_device_id = Column(String, index=True)
    encrypted_blob = Column(Text, nullable=False)
    status = Column(String, default="dispatched")
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
