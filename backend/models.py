from sqlalchemy import Column, String, DateTime
from database import Base
import datetime
import uuid

class User(Base):
    __tablename__ = "users"

    user_id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, index=True, nullable=False)
    device_id = Column(String, nullable=False)
    identity_key_pub = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class SosEvent(Base):
    __tablename__ = "sos_events"

    session_id = Column(String, primary_key=True, index=True)
    creator_device_id = Column(String, nullable=False)
    encrypted_blob = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)