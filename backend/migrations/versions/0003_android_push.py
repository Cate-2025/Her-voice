"""Durable Android push registration and delivery queue."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('push_devices',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('token', sa.String(1024), nullable=False, unique=True),
        sa.Column('active', sa.Boolean(), nullable=False))
    op.create_index('ix_push_devices_user_id', 'push_devices', ['user_id'])
    op.create_table('push_deliveries',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('notification_id', UUID(as_uuid=True), sa.ForeignKey('notifications.id', ondelete='CASCADE'), nullable=False),
        sa.Column('device_id', UUID(as_uuid=True), sa.ForeignKey('push_devices.id', ondelete='CASCADE'), nullable=False),
        sa.Column('state', sa.String(16), nullable=False),
        sa.Column('attempts', sa.Integer(), nullable=False),
        sa.Column('next_attempt_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('notification_id', 'device_id', name='uq_push_notice_device'))
    op.create_index('ix_push_deliveries_state', 'push_deliveries', ['state'])


def downgrade():
    op.drop_table('push_deliveries')
    op.drop_table('push_devices')
