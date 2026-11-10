import hashlib
from uuid import uuid4
from pathlib import Path

import pytest
from app.config import settings
from app.database import SessionLocal
from app.models import AuditLog, Evidence

DATA = b'%PDF-1.7\nFictional test fixture, not personal evidence.\n%%EOF'


@pytest.fixture(autouse=True)
def private_storage(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, 'evidence_storage', 'local')
    monkeypatch.setattr(settings, 'local_evidence_path', str(tmp_path / 'private'))


def draft(client, accounts, payload):
    return client.post('/api/v1/reports/drafts', json=payload, headers=accounts['student']['headers']).json()['id']


def upload(client, accounts, report_id, file_id, data=DATA, owner='student', checksum=None):
    return client.put(f'/api/v1/evidence/reports/{report_id}/files/{file_id}', content=data, headers={
        **accounts[owner]['headers'], 'Content-Type':'application/pdf', 'X-Evidence-Name':'example.pdf',
        'X-Evidence-SHA256':checksum or hashlib.sha256(data).hexdigest()})


def test_upload_retry_download_and_integrity(client, accounts, payload):
    report_id, file_id = draft(client, accounts, payload), uuid4()
    assert upload(client, accounts, report_id, file_id, owner='other').status_code == 404
    assert upload(client, accounts, report_id, file_id, owner='officer').status_code == 403
    first = upload(client, accounts, report_id, file_id)
    assert first.status_code == 200 and first.json()['verification_status'] == 'verified'
    assert upload(client, accounts, report_id, file_id).json() == first.json()
    download = f'/api/v1/evidence/{file_id}/file'
    assert client.get(download, headers=accounts['officer']['headers']).status_code == 404
    assert client.post(f'/api/v1/reports/{report_id}/submit', headers=accounts['student']['headers']).status_code == 200
    assert upload(client, accounts, report_id, file_id).status_code == 200
    assert upload(client, accounts, report_id, uuid4()).status_code == 409
    assert client.get(download, headers=accounts['student']['headers']).status_code == 403
    result = client.get(download, headers=accounts['officer']['headers'])
    assert result.content == DATA
    assert result.headers['cache-control'] == 'no-store'
    assert result.headers['content-disposition'].startswith('attachment;')
    detail = client.get(f'/api/v1/officer/cases/{report_id}', headers=accounts['officer']['headers']).json()
    assert detail['evidence'][0]['id'] == str(file_id)
    with SessionLocal() as db:
        assert db.query(Evidence).count() == 1
        assert db.query(AuditLog).filter_by(action='evidence_verified').count() == 1
        row = db.query(Evidence).one()
        (Path(settings.local_evidence_path) / row.object_key).write_bytes(b'changed')
    assert client.get(download, headers=accounts['officer']['headers']).status_code == 503


def test_bad_file_checksum_limit_and_quota(client, accounts, payload, monkeypatch):
    report_id = draft(client, accounts, payload)
    assert upload(client, accounts, report_id, uuid4(), checksum='a'*64).status_code == 422
    assert upload(client, accounts, report_id, uuid4(), data=b'not-a-pdf').status_code == 422
    monkeypatch.setattr(settings, 'max_evidence_bytes', 5)
    assert upload(client, accounts, report_id, uuid4()).status_code == 413
    monkeypatch.setattr(settings, 'max_evidence_bytes', 10*1024*1024)
    for _ in range(5): assert upload(client, accounts, report_id, uuid4()).status_code == 200
    assert upload(client, accounts, report_id, uuid4()).status_code == 409


def test_storage_failure_does_not_claim_verification(client, accounts, payload, monkeypatch):
    report_id, file_id = draft(client, accounts, payload), uuid4()
    def fail(*args): raise OSError('storage down')
    monkeypatch.setattr('app.routers.evidence.put_verified_bytes', fail)
    assert upload(client, accounts, report_id, file_id).status_code == 503
    with SessionLocal() as db:
        assert db.query(Evidence).count() == 0


def test_concurrent_upload_retries_keep_one_evidence_record(client, accounts, payload):
    from concurrent.futures import ThreadPoolExecutor
    report_id, file_id = draft(client, accounts, payload), uuid4()
    with ThreadPoolExecutor(max_workers=3) as pool:
        responses=list(pool.map(lambda _:upload(client,accounts,report_id,file_id),range(3)))
    assert all(response.status_code == 200 for response in responses)
    with SessionLocal() as db:
        assert db.query(Evidence).count() == 1
        assert db.query(AuditLog).filter_by(action='evidence_verified').count() == 1
