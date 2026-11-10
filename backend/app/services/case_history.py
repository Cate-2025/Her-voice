"""Student-safe status history from committed submission and transition records."""
from app.models import AuditLog, CaseStatus


def status_history(db, report):
    history = []
    if report.submitted_at:
        history.append({'status': CaseStatus.SUBMITTED, 'occurred_at': report.submitted_at})
    events = db.query(AuditLog).filter_by(report_id=report.id, action='case_status_changed').order_by(AuditLog.created_at, AuditLog.id).all()
    for event in events:
        status = event.details.get('to_status')
        if status in {value.value for value in CaseStatus}:
            history.append({'status': status, 'occurred_at': event.created_at})
    return history
