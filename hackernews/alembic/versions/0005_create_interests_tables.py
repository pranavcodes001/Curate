"""create interests tables

Revision ID: 0005
Revises: 0004
Create Date: 2026-02-06
"""
from alembic import op
import sqlalchemy as sa

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "interests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("group_name", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("keywords", sa.JSON(), nullable=False),
        sa.UniqueConstraint("group_name", "name", name="uq_interest_group_name"),
    )
    op.create_index("ix_interests_group_name", "interests", ["group_name"], unique=False)
    op.create_index("ix_interests_name", "interests", ["name"], unique=False)

    op.create_table(
        "user_interests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("interest_id", sa.Integer(), nullable=False),
        sa.UniqueConstraint("user_id", "interest_id", name="uq_user_interest"),
    )
    op.create_index("ix_user_interests_user_id", "user_interests", ["user_id"], unique=False)
    op.create_index("ix_user_interests_interest_id", "user_interests", ["interest_id"], unique=False)

    op.create_table(
        "interest_stories",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("interest_id", sa.Integer(), nullable=False),
        sa.Column("story_hn_id", sa.Integer(), nullable=False),
        sa.Column("points", sa.Integer(), nullable=True),
        sa.Column("time", sa.Integer(), nullable=True),
        sa.Column("read_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("interest_id", "story_hn_id", name="uq_interest_story"),
    )
    op.create_index("ix_interest_stories_interest_id", "interest_stories", ["interest_id"], unique=False)
    op.create_index("ix_interest_stories_story_hn_id", "interest_stories", ["story_hn_id"], unique=False)


def downgrade():
    op.drop_index("ix_interest_stories_story_hn_id", table_name="interest_stories")
    op.drop_index("ix_interest_stories_interest_id", table_name="interest_stories")
    op.drop_table("interest_stories")

    op.drop_index("ix_user_interests_interest_id", table_name="user_interests")
    op.drop_index("ix_user_interests_user_id", table_name="user_interests")
    op.drop_table("user_interests")

    op.drop_index("ix_interests_name", table_name="interests")
    op.drop_index("ix_interests_group_name", table_name="interests")
    op.drop_table("interests")
