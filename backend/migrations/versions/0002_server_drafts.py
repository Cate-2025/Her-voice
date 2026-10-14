"""Introduce server drafts and distinguish reserved evidence from verified uploads."""
from alembic import op
import sqlalchemy as sa

revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade():
    op.drop_constraint('reports_idempotency_key_key', 'reports', type_='unique')
    op.create_unique_constraint('uq_report_owner_operation', 'reports', ['reporter_id', 'idempotency_key'])
    op.add_column('reports', sa.Column('payload_sha256', sa.String(64), nullable=True))
    op.add_column('reports', sa.Column('submitted_at', sa.DateTime(timezone=True), nullable=True))
    # Legacy intake submitted immediately. Preserve its best available timestamp.
    op.execute("UPDATE reports SET submitted_at = created_at WHERE status <> 'DRAFT'")
    op.add_column('evidence', sa.Column('verification_status', sa.String(16), server_default='reserved', nullable=False))
    op.alter_column('evidence', 'uploaded_at', nullable=True, server_default=None)
    # Existing metadata timestamps do not establish that any object was uploaded.
    op.execute('UPDATE evidence SET uploaded_at = NULL')


def downgrade():
    # Fail without changing data if account-scoped keys cannot fit the old schema.
    op.execute("""DO $$ BEGIN
        IF EXISTS (SELECT idempotency_key FROM reports WHERE idempotency_key IS NOT NULL
                   GROUP BY idempotency_key HAVING count(*) > 1) THEN
            RAISE EXCEPTION 'Cannot downgrade: idempotency keys are shared across accounts';
        END IF;
    END $$""")
    op.drop_constraint('uq_report_owner_operation', 'reports', type_='unique')
    op.create_unique_constraint('reports_idempotency_key_key', 'reports', ['idempotency_key'])
    op.drop_column('reports', 'payload_sha256')
    op.drop_column('reports', 'submitted_at')
    op.execute('UPDATE evidence SET uploaded_at = CURRENT_TIMESTAMP WHERE uploaded_at IS NULL')
    op.alter_column('evidence', 'uploaded_at', nullable=False, server_default=sa.text('now()'))
    op.drop_column('evidence', 'verification_status')
