from uuid import UUID

from functools import lru_cache
import boto3
from botocore.config import Config

from app.config import settings

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "application/pdf", "audio/mpeg", "audio/mp4"}


def object_key(report_id: UUID, evidence_id: UUID) -> str:
    """Never use an original filename in the storage key."""
    return f"reports/{report_id}/{evidence_id}"


@lru_cache(maxsize=1)
def storage_client():
    return boto3.client(
        "s3",
        config=Config(connect_timeout=2, read_timeout=3, retries={"total_max_attempts": 1},
                      signature_version='s3v4', s3={'addressing_style': 'path'}),
        region_name=settings.object_storage_region,
        endpoint_url=settings.object_storage_endpoint,
        aws_access_key_id=settings.object_storage_access_key,
        aws_secret_access_key=settings.object_storage_secret_key,
    )


def presigned_upload_url(key: str, content_type: str) -> str:
    return storage_client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.object_storage_bucket, "Key": key, "ContentType": content_type},
        ExpiresIn=300,
        HttpMethod="PUT",
    )


def presigned_download_url(key: str) -> str:
    return storage_client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.object_storage_bucket, "Key": key},
        ExpiresIn=120,
    )


def put_verified_bytes(key: str, data: bytes, content_type: str) -> None:
    """Only server-controlled keys are writable; client upload URLs never target these."""
    if settings.evidence_storage == 'local':
        from pathlib import Path
        import os
        import tempfile
        root = Path(settings.local_evidence_path).resolve()
        root.mkdir(parents=True, exist_ok=True, mode=0o700)
        path = root / key
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        fd, temp = tempfile.mkstemp(dir=path.parent, prefix='.upload-')
        try:
            with os.fdopen(fd, 'wb') as file:
                file.write(data)
                file.flush()
                os.fsync(file.fileno())
            os.replace(temp, path)
        finally:
            if os.path.exists(temp): os.unlink(temp)
    else:
        storage_client().put_object(Bucket=settings.object_storage_bucket, Key=key,
                                    Body=data, ContentType=content_type)


def read_verified_bytes(key: str) -> bytes:
    if settings.evidence_storage == 'local':
        from pathlib import Path
        with (Path(settings.local_evidence_path).resolve() / key).open('rb') as file:
            data = file.read(settings.max_evidence_bytes + 1)
        if len(data) > settings.max_evidence_bytes: raise ValueError('Stored evidence too large')
        return data
    response = storage_client().get_object(Bucket=settings.object_storage_bucket, Key=key)
    body = response['Body']
    try:
        data = body.read(settings.max_evidence_bytes + 1)
        if len(data) > settings.max_evidence_bytes: raise ValueError('Stored evidence too large')
        return data
    finally:
        body.close()


def matches_file_signature(data: bytes, content_type: str) -> bool:
    # Signature screening is not malware scanning or a credibility assessment.
    return {
        'image/jpeg': data.startswith(b'\xff\xd8\xff'),
        'image/png': data.startswith(b'\x89PNG\r\n\x1a\n'),
        'application/pdf': data.startswith(b'%PDF-'),
        'audio/mpeg': data.startswith(b'ID3') or (len(data) > 1 and data[0] == 255 and data[1] & 224 == 224),
        'audio/mp4': len(data) >= 12 and data[4:8] == b'ftyp' and data[8:12] in (b'M4A ', b'M4B ', b'mp42', b'isom'),
    }.get(content_type, False)
