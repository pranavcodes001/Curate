"""add user name

Revision ID: 0008
Revises: 0007
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("users", sa.Column("name", sa.String(), nullable=True))


def downgrade():
    op.drop_column("users", "name")
