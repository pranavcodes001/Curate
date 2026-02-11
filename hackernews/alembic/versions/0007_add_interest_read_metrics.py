"""add interest read metrics

Revision ID: 0007
Revises: 0006
Create Date: 2026-02-06
"""
from alembic import op
import sqlalchemy as sa

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("interests", sa.Column("read_count", sa.Integer(), nullable=False, server_default=sa.text("0")))
    op.add_column("interests", sa.Column("last_read_at", sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column("interests", "last_read_at")
    op.drop_column("interests", "read_count")
