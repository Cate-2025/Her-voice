from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from sqlalchemy.dialects.postgresql import insert
from app.models import Notification, User, PushDevice, Role
from app.schemas import PushDeviceRequest
from app.security import require_roles
from app.schemas import NotificationResponse
from app.security import get_current_user

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationResponse])
def list_notifications(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Notification]:
    return db.query(Notification).filter(Notification.user_id == user.id).order_by(Notification.created_at.desc()).all()


@router.post("/read-all", response_model=list[NotificationResponse])
def mark_all_read(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Notification]:
    db.query(Notification).filter(
        Notification.user_id == user.id, Notification.read_at.is_(None),
    ).update({Notification.read_at: datetime.now(UTC)}, synchronize_session=False)
    db.commit()
    return list_notifications(user, db)


@router.post("/{notification_id}/read", response_model=NotificationResponse)
def mark_read(notification_id: UUID, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Notification:
    notification = db.get(Notification, notification_id)
    if not notification or notification.user_id != user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    if notification.read_at is None:
        notification.read_at = datetime.now(UTC)
    db.commit()
    db.refresh(notification)
    return notification


@router.post("/devices/register")
def register_device(payload: PushDeviceRequest, user: User = Depends(require_roles(Role.STUDENT)), db: Session = Depends(get_db)) -> dict:
    # A token belongs to one signed-in account. Reassigning it cannot send the
    # previous owner's queued notifications: the worker rechecks ownership.
    statement = insert(PushDevice).values(user_id=user.id, token=payload.token, active=True)
    db.execute(statement.on_conflict_do_update(index_elements=[PushDevice.token], set_={"user_id": user.id, "active": True}))
    db.commit()
    return {"registered": True}


@router.post("/devices/revoke")
def revoke_device(payload: PushDeviceRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    db.query(PushDevice).filter(PushDevice.user_id == user.id, PushDevice.token == payload.token).update({PushDevice.active: False})
    db.commit()
    return {"registered": False}
