"""create top_stories, user_story_state, search_queries

Revision ID: 0006
Revises: 0005
Create Date: 2026-02-06
"""
from alembic import op
import sqlalchemy as sa

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "top_stories",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("hn_id", sa.Integer(), nullable=False),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column("fetched_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("hn_id", name="uq_top_story_hn_id"),
    )
    op.create_index("ix_top_stories_hn_id", "top_stories", ["hn_id"], unique=False)
    op.create_index("ix_top_stories_rank", "top_stories", ["rank"], unique=False)

    op.create_table(
        "user_story_state",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("story_hn_id", sa.Integer(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(), nullable=True),
        sa.Column("last_read_at", sa.DateTime(), nullable=True),
        sa.Column("read_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.UniqueConstraint("user_id", "story_hn_id", name="uq_user_story_state"),
    )
    op.create_index("ix_user_story_state_user_id", "user_story_state", ["user_id"], unique=False)
    op.create_index("ix_user_story_state_story_hn_id", "user_story_state", ["story_hn_id"], unique=False)

    op.create_table(
        "search_queries",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("query", sa.String(), nullable=False),
        sa.Column("limit", sa.Integer(), nullable=False),
        sa.Column("results", sa.JSON(), nullable=False),
        sa.Column("fetched_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("query", "limit", name="uq_search_query_limit"),
    )
    op.create_index("ix_search_queries_query", "search_queries", ["query"], unique=False)


def downgrade():
    op.drop_index("ix_search_queries_query", table_name="search_queries")
    op.drop_table("search_queries")

    op.drop_index("ix_user_story_state_story_hn_id", table_name="user_story_state")
    op.drop_index("ix_user_story_state_user_id", table_name="user_story_state")
    op.drop_table("user_story_state")

    op.drop_index("ix_top_stories_rank", table_name="top_stories")
    op.drop_index("ix_top_stories_hn_id", table_name="top_stories")
    op.drop_table("top_stories")
