"""add url to saved_threads

Revision ID: 0010
Revises: 0009
Create Date: 2026-02-13
"""
from alembic import op
import sqlalchemy as sa

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("saved_threads", sa.Column("url", sa.String(), nullable=True))


def downgrade():
    op.drop_column("saved_threads", "url")
