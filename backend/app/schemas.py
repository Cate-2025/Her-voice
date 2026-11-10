from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models import CaseStatus, ReportMode, Role


class LoginRequest(BaseModel):
    email: str = Field(max_length=255)
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TimelineEventCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    occurred_at: datetime
    location_hint: str | None = Field(default=None, max_length=255)
    narrative: str = Field(min_length=1, max_length=10_000)

    @field_validator("occurred_at")
    @classmethod
    def timezone_required(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("Date and time must include a timezone offset")
        return value


class ReportCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
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
    submitted_at: datetime | None


class OfficerReportResponse(ReportResponse):
    assigned_officer_id: UUID | None


class OfficerCasePage(BaseModel):
    items: list[OfficerReportResponse]
    total: int


class OfficerQueueSummary(BaseModel):
    total: int
    submitted: int
    under_review: int
    alerts: int


class OfficerAlertPage(BaseModel):
    items: list["PatternAlertResponse"]
    total: int


class TimelineEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    occurred_at: datetime
    location_hint: str | None
    narrative: str


class OfficerCaseDetail(OfficerReportResponse):
    timeline: list[TimelineEventResponse]
    evidence: list["EvidenceSummary"] = Field(default_factory=list)


class CaseStatusUpdate(BaseModel):
    status: CaseStatus
    expected_status: CaseStatus | None = None


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


class EvidenceSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    original_name: str
    content_type: str
    byte_size: int
    verification_status: str


class StatusHistoryEvent(BaseModel):
    status: CaseStatus
    occurred_at: datetime


class StudentReportDetail(ReportResponse):
    status_history: list[StatusHistoryEvent] = Field(default_factory=list)
    timeline: list[TimelineEventResponse]
    evidence: list[EvidenceSummary]


class IdentityAccessRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    reason: str = Field(min_length=10, max_length=500)


class ReporterIdentityResponse(BaseModel):
    email: str


class PushDeviceRequest(BaseModel):
    token: str = Field(min_length=20, max_length=1024, pattern=r"^\S+$")


class EmailCodeRequest(BaseModel):
    email: str = Field(max_length=255)
    purpose: str = Field(pattern=r'^(register|reset)$')

    @field_validator('email')
    @classmethod
    def valid_email(cls, value):
        from email_validator import validate_email, EmailNotValidError
        try:
            return validate_email(value.strip(), check_deliverability=False, test_environment=True).normalized.lower()
        except EmailNotValidError:
            raise ValueError('Enter a valid email address')


class EmailCodeComplete(EmailCodeRequest):
    code: str = Field(pattern=r'^\d{8}$')
    password: str = Field(min_length=12, max_length=128)
