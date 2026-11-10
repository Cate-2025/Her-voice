"""Transactional outbox. Provider acceptance is not proof of phone delivery."""
from datetime import UTC, datetime, timedelta
import logging
from threading import Event

from app.database import SessionLocal
from app.models import Notification, PushDevice, PushDelivery, User

logger = logging.getLogger(__name__)


def queue_push(db, notification):
    for device in db.query(PushDevice).filter_by(user_id=notification.user_id, active=True):
        db.add(PushDelivery(notification_id=notification.id, device_id=device.id))


class InvalidDevice(Exception):
    pass


class FirebaseSender:
    def __init__(self):
        import firebase_admin
        from firebase_admin import credentials
        # Fail startup visibly when push was explicitly enabled without credentials.
        self.app = firebase_admin.initialize_app(credentials.ApplicationDefault(), options={'httpTimeout': 10}, name='hervoice-push')
        self.app.credential.get_credential()

    def __call__(self, token, notification_id):
        from firebase_admin import messaging
        try:
            messaging.send(messaging.Message(
                token=token,
                notification=messaging.Notification(title='HERVOICE', body='You have a new update. Open HERVOICE to view it.'),
                data={'screen': 'updates'},
                android=messaging.AndroidConfig(priority='normal', ttl=timedelta(hours=1),
                    notification=messaging.AndroidNotification(tag=str(notification_id), visibility='private')),
            ), app=self.app)
        except (messaging.UnregisteredError, messaging.SenderIdMismatchError) as error:
            raise InvalidDevice() from error

    def close(self):
        import firebase_admin
        firebase_admin.delete_app(self.app)


def deliver_one(sender):
    with SessionLocal() as db:
        delivery = db.query(PushDelivery).filter(
            PushDelivery.state == 'pending', PushDelivery.next_attempt_at <= datetime.now(UTC),
        ).order_by(PushDelivery.next_attempt_at).with_for_update(skip_locked=True).first()
        if delivery is None:
            return False
        device = db.query(PushDevice).filter_by(id=delivery.device_id).with_for_update().one()
        notice = db.get(Notification, delivery.notification_id)
        user = db.get(User, device.user_id)
        if not device.active or device.user_id != notice.user_id or not user.is_active or notice.read_at is not None:
            delivery.state = 'skipped'
        else:
            delivery.attempts += 1
            try:
                sender(device.token, notice.id)
                delivery.state = 'sent'
            except InvalidDevice:
                device.active = False
                delivery.state = 'skipped'
            except Exception:
                # Never log provider exception strings, which can contain tokens.
                delivery.state = 'failed' if delivery.attempts >= 5 else 'pending'
                delivery.next_attempt_at = datetime.now(UTC) + timedelta(seconds=30 * 2 ** delivery.attempts)
                logger.warning('Push delivery attempt failed; state=%s', delivery.state)
        db.commit()
        return True


def run_worker(stop: Event, sender):
    while not stop.is_set():
        try:
            if deliver_one(sender):
                continue
        except Exception:
            logger.warning('Push queue unavailable; will retry')
        stop.wait(5)
