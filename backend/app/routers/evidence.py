import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import CaseStatus, Evidence, Report, Role, User
from app.schemas import EvidenceDownloadTarget, EvidenceUploadRequest, EvidenceUploadTarget
from app.security import get_current_user, require_roles
from app.services.storage import ALLOWED_MIME_TYPES, object_key, presigned_download_url, presigned_upload_url

router = APIRouter(prefix="/api/v1/evidence", tags=["evidence"])


def owned_report(db: Session, report_id: uuid.UUID, user: User) -> Report:
    report = db.query(Report).filter(Report.id == report_id).with_for_update().one_or_none()
    if not report or report.reporter_id != user.id:
        raise HTTPException(status_code=404, detail="Report not found")
    return report


@router.post("/reports/{report_id}/upload-url", response_model=EvidenceUploadTarget, status_code=status.HTTP_201_CREATED)
def create_upload_target(
    report_id: uuid.UUID,
    payload: EvidenceUploadRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> EvidenceUploadTarget:
    if user.role != Role.STUDENT:
        raise HTTPException(status_code=403, detail="Student access required")
    report = owned_report(db, report_id, user)
    if report.status != CaseStatus.DRAFT:
        raise HTTPException(status_code=409, detail="Evidence can only be added to a server draft")
    if payload.content_type not in ALLOWED_MIME_TYPES or payload.byte_size > settings.max_evidence_bytes:
        raise HTTPException(status_code=400, detail="Evidence type or size is not permitted")
    evidence_id = uuid.uuid4()
    key = object_key(report_id, evidence_id)
    db.add(Evidence(id=evidence_id, report_id=report_id, object_key=key, original_name=payload.original_name,
                    content_type=payload.content_type, byte_size=payload.byte_size, sha256=payload.sha256))
    db.commit()
    return EvidenceUploadTarget(evidence_id=evidence_id, object_key=key, upload_url=presigned_upload_url(key, payload.content_type))


@router.get("/{evidence_id}/download-url", response_model=EvidenceDownloadTarget)
def evidence_download_url(
    evidence_id: uuid.UUID,
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
) -> EvidenceDownloadTarget:
    evidence = db.get(Evidence, evidence_id)
    report = db.get(Report, evidence.report_id) if evidence else None
    if not evidence or not report or report.status == CaseStatus.DRAFT:
        raise HTTPException(status_code=404, detail="Evidence not found")
    if evidence.verification_status != "verified":
        raise HTTPException(status_code=409, detail="Evidence has not been verified")
    return EvidenceDownloadTarget(download_url=presigned_download_url(evidence.object_key))
