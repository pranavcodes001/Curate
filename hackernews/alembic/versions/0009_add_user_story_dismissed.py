"""add dismissed_at to user_story_state

Revision ID: 0009
Revises: 0008
Create Date: 2026-02-10
"""
from alembic import op
import sqlalchemy as sa

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("user_story_state", sa.Column("dismissed_at", sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column("user_story_state", "dismissed_at")
