from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models import CaseStatus, ReportMode, Role


class LoginRequest(BaseModel):
    email: str = Field(max_length=255)
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TimelineEventCreate(BaseModel):
    occurred_at: datetime
    location_hint: str | None = Field(default=None, max_length=255)
    narrative: str = Field(min_length=1, max_length=10_000)


class ReportCreate(BaseModel):
    report_mode: ReportMode
    subject_staff_ref: str = Field(min_length=2, max_length=128)
    course_ref: str | None = Field(default=None, max_length=128)
    idempotency_key: str = Field(min_length=16, max_length=128)
    timeline: list[TimelineEventCreate] = Field(min_length=1, max_length=50)


class ReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    report_mode: ReportMode
    case_code: str | None
    subject_staff_ref: str
    course_ref: str | None
    status: CaseStatus
    created_at: datetime


class OfficerReportResponse(ReportResponse):
    assigned_officer_id: UUID | None


class TimelineEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    occurred_at: datetime
    location_hint: str | None
    narrative: str


class OfficerCaseDetail(OfficerReportResponse):
    timeline: list[TimelineEventResponse]


class CaseStatusUpdate(BaseModel):
    status: CaseStatus


class EvidenceUploadRequest(BaseModel):
    original_name: str = Field(min_length=1, max_length=255)
    content_type: str = Field(pattern=r"^(image/(jpeg|png)|application/pdf|audio/(mpeg|mp4))$")
    byte_size: int = Field(gt=0)
    sha256: str = Field(pattern=r"^[a-fA-F0-9]{64}$")


class EvidenceUploadTarget(BaseModel):
    evidence_id: UUID
    object_key: str
    upload_url: str


class EvidenceDownloadTarget(BaseModel):
    download_url: str


class PatternAlertResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    staff_ref: str
    report_count: int
    window_start: datetime
    window_end: datetime
    reviewed_at: datetime | None


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    body: str
    read_at: datetime | None
    created_at: datetime


class UserSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: str
    role: Role
