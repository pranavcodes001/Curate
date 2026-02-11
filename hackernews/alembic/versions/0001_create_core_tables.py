"""create core tables

Revision ID: 0001
Revises: 
Create Date: 2026-02-05
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'stories',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('hn_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(), nullable=True),
        sa.Column('url', sa.String(), nullable=True),
        sa.Column('raw_payload', sa.JSON(), nullable=True),
        sa.Column('content_hash', sa.String(length=128), nullable=True),
        sa.Column('last_fetched_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_stories_hn_id', 'stories', ['hn_id'], unique=True)
    op.create_index('ix_stories_content_hash', 'stories', ['content_hash'], unique=False)

    op.create_table(
        'ai_summaries',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('story_hn_id', sa.Integer(), nullable=False),
        sa.Column('model_name', sa.String(), nullable=True),
        sa.Column('model_version', sa.String(), nullable=False),
        sa.Column('content_hash', sa.String(length=128), nullable=False),
        sa.Column('tldr', sa.String(), nullable=True),
        sa.Column('key_points', sa.JSON(), nullable=True),
        sa.Column('consensus', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.UniqueConstraint('story_hn_id', 'model_version', name='uq_story_modelver'),
    )
    op.create_index('ix_ai_summaries_story_hn_id', 'ai_summaries', ['story_hn_id'], unique=False)
    op.create_index('ix_ai_summaries_content_hash', 'ai_summaries', ['content_hash'], unique=False)


def downgrade():
    op.drop_index('ix_ai_summaries_content_hash', table_name='ai_summaries')
    op.drop_index('ix_ai_summaries_story_hn_id', table_name='ai_summaries')
    op.drop_table('ai_summaries')

    op.drop_index('ix_stories_content_hash', table_name='stories')
    op.drop_index('ix_stories_hn_id', table_name='stories')
    op.drop_table('stories')
