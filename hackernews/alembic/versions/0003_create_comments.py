"""create comments table

Revision ID: 0003
Revises: 0002
Create Date: 2026-02-06
"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "comments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("comment_hn_id", sa.Integer(), nullable=False),
        sa.Column("story_hn_id", sa.Integer(), nullable=False),
        sa.Column("parent_hn_id", sa.Integer(), nullable=True),
        sa.Column("author", sa.String(), nullable=True),
        sa.Column("time", sa.Integer(), nullable=True),
        sa.Column("text", sa.Text(), nullable=True),
        sa.Column("raw_payload", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_comments_comment_hn_id", "comments", ["comment_hn_id"], unique=True)
    op.create_index("ix_comments_story_hn_id", "comments", ["story_hn_id"], unique=False)
    op.create_index("ix_comments_parent_hn_id", "comments", ["parent_hn_id"], unique=False)
    op.create_index("ix_comments_story_time", "comments", ["story_hn_id", "time"], unique=False)


def downgrade():
    op.drop_index("ix_comments_story_time", table_name="comments")
    op.drop_index("ix_comments_parent_hn_id", table_name="comments")
    op.drop_index("ix_comments_story_hn_id", table_name="comments")
    op.drop_index("ix_comments_comment_hn_id", table_name="comments")
    op.drop_table("comments")
