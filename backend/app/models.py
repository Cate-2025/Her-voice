import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Role(str, enum.Enum):
    STUDENT = "student"
    OFFICER = "officer"
    ADMIN = "admin"


class ReportMode(str, enum.Enum):
    IDENTIFIED = "identified"
    CONFIDENTIAL = "confidential"
    ANONYMOUS = "anonymous"


class CaseStatus(str, enum.Enum):
    DRAFT = "draft"
    SUBMITTED = "submitted"
    RECEIVED = "received"
    UNDER_REVIEW = "under_review"
    ACTION_REQUIRED = "action_required"
    CLOSED = "closed"


class User(Base):
    __tablename__ = "users"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[Role] = mapped_column(Enum(Role), default=Role.STUDENT)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Report(Base):
    __tablename__ = "reports"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reporter_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)
    report_mode: Mapped[ReportMode] = mapped_column(Enum(ReportMode), nullable=False)
    case_code: Mapped[str | None] = mapped_column(String(32), unique=True, nullable=True, index=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)
    subject_staff_ref: Mapped[str] = mapped_column(String(128), index=True)
    course_ref: Mapped[str | None] = mapped_column(String(128), nullable=True)
    status: Mapped[CaseStatus] = mapped_column(Enum(CaseStatus), default=CaseStatus.DRAFT, index=True)
    assigned_officer_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class TimelineEvent(Base):
    __tablename__ = "timeline_events"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    report_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("reports.id", ondelete="CASCADE"), index=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    location_hint: Mapped[str | None] = mapped_column(String(255), nullable=True)
    narrative: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Evidence(Base):
    __tablename__ = "evidence"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    report_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("reports.id", ondelete="CASCADE"), index=True)
    object_key: Mapped[str] = mapped_column(String(512), unique=True)
    original_name: Mapped[str] = mapped_column(String(255))
    content_type: Mapped[str] = mapped_column(String(128))
    byte_size: Mapped[int] = mapped_column(Integer)
    sha256: Mapped[str] = mapped_column(String(64))
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    body: Mapped[str] = mapped_column(String(160), default="You have a new confidential update.")
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String(100))
    report_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("reports.id"), nullable=True)
    details: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class PatternAlert(Base):
    __tablename__ = "pattern_alerts"
    __table_args__ = (UniqueConstraint("staff_ref", "window_start", name="uq_pattern_window"),)
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    staff_ref: Mapped[str] = mapped_column(String(128), index=True)
    report_count: Mapped[int] = mapped_column(Integer)
    window_start: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    window_end: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
