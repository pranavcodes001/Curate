"""create saved threads and comment summaries

Revision ID: 0004
Revises: 0003
Create Date: 2026-02-06
"""
from alembic import op
import sqlalchemy as sa

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "comment_summaries",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("comment_hn_id", sa.Integer(), nullable=False),
        sa.Column("model_name", sa.String(), nullable=True),
        sa.Column("model_version", sa.String(), nullable=False),
        sa.Column("tldr", sa.String(), nullable=True),
        sa.Column("key_points", sa.JSON(), nullable=True),
        sa.Column("consensus", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("comment_hn_id", "model_version", name="uq_comment_modelver"),
    )
    op.create_index("ix_comment_summaries_comment_hn_id", "comment_summaries", ["comment_hn_id"], unique=False)

    op.create_table(
        "saved_threads",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("story_hn_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_saved_threads_user_id", "saved_threads", ["user_id"], unique=False)
    op.create_index("ix_saved_threads_story_hn_id", "saved_threads", ["story_hn_id"], unique=False)

    op.create_table(
        "saved_thread_items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("saved_thread_id", sa.Integer(), nullable=False),
        sa.Column("item_type", sa.String(), nullable=False),
        sa.Column("hn_id", sa.Integer(), nullable=False),
        sa.Column("raw_text", sa.Text(), nullable=True),
        sa.Column("ai_summary", sa.JSON(), nullable=True),
        sa.Column("model_name", sa.String(), nullable=True),
        sa.Column("model_version", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_saved_thread_items_thread_id", "saved_thread_items", ["saved_thread_id"], unique=False)
    op.create_index("ix_saved_thread_items_hn_id", "saved_thread_items", ["hn_id"], unique=False)


def downgrade():
    op.drop_index("ix_saved_thread_items_hn_id", table_name="saved_thread_items")
    op.drop_index("ix_saved_thread_items_thread_id", table_name="saved_thread_items")
    op.drop_table("saved_thread_items")

    op.drop_index("ix_saved_threads_story_hn_id", table_name="saved_threads")
    op.drop_index("ix_saved_threads_user_id", table_name="saved_threads")
    op.drop_table("saved_threads")

    op.drop_index("ix_comment_summaries_comment_hn_id", table_name="comment_summaries")
    op.drop_table("comment_summaries")
