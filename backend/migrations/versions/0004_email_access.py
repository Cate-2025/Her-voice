"""Verified email access and revocable password-reset sessions."""
from alembic import op
import sqlalchemy as sa
revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('users', sa.Column('token_version',sa.Integer(),server_default='0',nullable=False))
    op.create_table('email_challenges',
        sa.Column('email',sa.String(255),primary_key=True),
        sa.Column('purpose',sa.String(16),primary_key=True),
        sa.Column('code_hash',sa.String(64),nullable=False),
        sa.Column('expires_at',sa.DateTime(timezone=True),nullable=False),
        sa.Column('sent_at',sa.DateTime(timezone=True),nullable=False),
        sa.Column('attempts',sa.Integer(),nullable=False))
    op.create_table('auth_throttles',
        sa.Column('key',sa.String(64),primary_key=True),
        sa.Column('window_start',sa.DateTime(timezone=True),nullable=False),
        sa.Column('count',sa.Integer(),nullable=False))


def downgrade():
    op.drop_table('auth_throttles')
    op.drop_table('email_challenges')
    op.drop_column('users','token_version')
