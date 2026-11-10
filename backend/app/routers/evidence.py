import uuid
import asyncio
import hashlib
import re
from datetime import UTC, datetime
from urllib.parse import quote, unquote
from fastapi import Request, Response
from starlette.concurrency import run_in_threadpool
from app.models import AuditLog
from app.schemas import EvidenceSummary
from app.services.storage import put_verified_bytes, read_verified_bytes, matches_file_signature

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import CaseStatus, Evidence, Report, Role, User
from app.schemas import EvidenceDownloadTarget, EvidenceUploadRequest, EvidenceUploadTarget
from app.security import get_current_user, require_roles
from app.services.storage import ALLOWED_MIME_TYPES

router = APIRouter(prefix="/api/v1/evidence", tags=["evidence"])


def owned_report(db: Session, report_id: uuid.UUID, user: User) -> Report:
    report = db.query(Report).filter(Report.id == report_id).with_for_update().one_or_none()
    if not report or report.reporter_id != user.id:
        raise HTTPException(status_code=404, detail="Report not found")
    return report


@router.post("/reports/{report_id}/upload-url", response_model=None, status_code=410, deprecated=True)
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
    raise HTTPException(status_code=410, detail='Use authenticated PUT /evidence/reports/{report_id}/files/{evidence_id}')


@router.get("/{evidence_id}/download-url", response_model=None, status_code=410, deprecated=True)
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
    raise HTTPException(status_code=410, detail='Use the authenticated evidence file endpoint')


@router.put('/reports/{report_id}/files/{evidence_id}', response_model=EvidenceSummary)
async def upload_file(
    report_id: uuid.UUID, evidence_id: uuid.UUID, request: Request,
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
) -> Evidence:
    if user.role != Role.STUDENT:
        raise HTTPException(status_code=403, detail='Student access required')
    # Do not hold a database row lock while awaiting client bytes: another
    # synchronous lock attempt must never block the event loop that receives them.
    permitted = await run_in_threadpool(lambda: db.query(Report.id).filter(
        Report.id == report_id, Report.reporter_id == user.id).first())
    if not permitted:
        raise HTTPException(status_code=404, detail='Report not found')
    content_type = request.headers.get('content-type', '').split(';')[0]
    checksum = request.headers.get('x-evidence-sha256', '')
    name = unquote(request.headers.get('x-evidence-name', ''))
    if content_type not in ALLOWED_MIME_TYPES or not re.fullmatch('[a-f0-9]{64}', checksum):
        raise HTTPException(status_code=422, detail='Invalid evidence metadata')
    if not name.strip() or len(name) > 255 or any(ord(c) < 32 for c in name) or '/' in name or chr(92) in name:
        raise HTTPException(status_code=422, detail='Invalid evidence filename')
    data = bytearray()
    try:
        async with asyncio.timeout(60):
            async for chunk in request.stream():
                if len(data) + len(chunk) > settings.max_evidence_bytes:
                    raise HTTPException(status_code=413, detail='Evidence is too large')
                data.extend(chunk)
    except TimeoutError:
        raise HTTPException(status_code=408, detail='Evidence transfer timed out')
    return await run_in_threadpool(_store_upload, db, user, report_id, evidence_id,
                                  name, content_type, checksum, bytes(data))


def _store_upload(db, user, report_id, evidence_id, name, content_type, checksum, data):
    report = owned_report(db, report_id, user)
    if not data or hashlib.sha256(data).hexdigest() != checksum or not matches_file_signature(data, content_type):
        raise HTTPException(status_code=422, detail='Evidence content does not match declared metadata')
    existing = db.get(Evidence, evidence_id)
    if existing:
        if existing.report_id != report.id:
            raise HTTPException(status_code=409, detail='Evidence reference already used')
        if (existing.sha256, existing.original_name, existing.content_type, existing.byte_size) != (checksum, name, content_type, len(data)):
            raise HTTPException(status_code=409, detail='Evidence reference reused with different content')
        if existing.verification_status == 'verified':
            return existing
    if report.status != CaseStatus.DRAFT:
        raise HTTPException(status_code=409, detail='Only drafts can receive evidence')
    if not existing and db.query(Evidence).filter_by(report_id=report.id).count() >= 5:
        raise HTTPException(status_code=409, detail='Up to five files per report')
    key = f'verified/{report.id}/{evidence_id}/{checksum}'
    try:
        put_verified_bytes(key, data, content_type)
        stored = read_verified_bytes(key)
        if len(stored) != len(data) or hashlib.sha256(stored).hexdigest() != checksum:
            raise ValueError('Storage verification failed')
    except Exception:
        raise HTTPException(status_code=503, detail='Evidence storage unavailable; retry this upload')
    evidence = existing or Evidence(id=evidence_id, report_id=report.id, original_name=name,
                                    content_type=content_type, byte_size=len(data), sha256=checksum)
    evidence.object_key = key
    evidence.verification_status = 'verified'
    evidence.uploaded_at = datetime.now(UTC)
    db.add(evidence)
    db.add(AuditLog(actor_id=user.id, action='evidence_verified', report_id=report.id, details={'evidence_id':str(evidence.id)}))
    db.commit()
    db.refresh(evidence)
    return evidence


@router.get('/{evidence_id}/file')
def download_file(evidence_id: uuid.UUID, officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)), db: Session = Depends(get_db)):
    evidence = db.get(Evidence, evidence_id)
    report = db.get(Report, evidence.report_id) if evidence else None
    if not evidence or not report or report.status == CaseStatus.DRAFT:
        raise HTTPException(status_code=404, detail='Evidence not found')
    if evidence.verification_status != 'verified':
        raise HTTPException(status_code=409, detail='Evidence not verified')
    try:
        data = read_verified_bytes(evidence.object_key)
        if len(data) != evidence.byte_size or hashlib.sha256(data).hexdigest() != evidence.sha256:
            raise ValueError('Stored bytes changed')
    except Exception:
        raise HTTPException(status_code=503, detail='Verified evidence unavailable')
    db.add(AuditLog(actor_id=officer.id, action='evidence_download_authorized', report_id=report.id, details={'evidence_id':str(evidence.id)}))
    db.commit()
    return Response(data, media_type='application/octet-stream', headers={
        'Content-Disposition': "attachment; filename*=UTF-8''" + quote(evidence.original_name, safe=''),
        'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
    })
