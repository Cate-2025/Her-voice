from uuid import UUID

import boto3

from app.config import settings

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "application/pdf", "audio/mpeg", "audio/mp4"}


def object_key(report_id: UUID, evidence_id: UUID) -> str:
    """Never use an original filename in the storage key."""
    return f"reports/{report_id}/{evidence_id}"


def storage_client():
    return boto3.client(
        "s3",
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
