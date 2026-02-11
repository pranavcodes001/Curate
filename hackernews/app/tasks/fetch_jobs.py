"""Orchestrates fetching from Hacker News and persisting + priming cache."""
from typing import Sequence, Tuple
import asyncio
import logging

from app.services.sources.hackernews.fetcher import HNFetcher, StoryData
from app.repositories.story_repo import StoryRepository
from app.repositories.top_story_repo import TopStoryRepository
from app.services.cache.feed_cache import FeedCache
from app.db.session import get_session

logger = logging.getLogger(__name__)


async def run_fetch_once(
    SessionLocal,
    fetcher: HNFetcher,
    repo: StoryRepository,
    feed_cache: FeedCache,
    limit: int,
    *,
    top_story_repo: TopStoryRepository | None = None,
    provider=None,
    summary_repo=None,
    summary_cache=None,
    model_version: str | None = None,
) -> Tuple[int, int]:
    """Run a single top-stories refresh cycle:
    - fetch top ids
    - fetch and normalize story payloads (concurrently)
    - upsert into DB
    - replace top_stories list
    - prime top-stories cache

    Returns (inserted_count, updated_count)
    """
    top_ids = await fetcher.fetch_top_ids()
    # de-duplicate while preserving order
    seen = set()
    deduped = []
    for i in list(top_ids):
        if i in seen:
            continue
        seen.add(i)
        deduped.append(i)
    top_ids = deduped[:limit]
    if not top_ids:
        logger.info("No top ids returned")
        return 0, 0

    # fetch all items concurrently
    coros = [fetcher.fetch_and_normalize(i) for i in top_ids]
    results: Sequence[StoryData] = await asyncio.gather(*coros, return_exceptions=False)

    inserted = 0
    updated = 0

    # persist synchronously using session context manager
    with get_session(SessionLocal) as session:
        for sd in results:
            try:
                story, created, was_updated = repo.upsert(session, sd)
                if created:
                    inserted += 1
                if was_updated:
                    updated += 1

                # schedule summarization if enabled and provider/repo/cache supplied
                try:
                    if (created or was_updated) and settings.ENABLE_SUMMARIZATION and provider and summary_repo and summary_cache:
                        mv = model_version or settings.SUMMARIZATION_MODEL_VERSION

                        # background task: create its own session and call the hook
                        async def _background_summary(sd_local: StoryData, mv_local: str):
                            try:
                                from app.db.session import get_session as _get_session

                                # open independent session for background work
                                with _get_session(SessionLocal) as bg_session:
                                    # create a minimal story_row object expected by the hook
                                    class StoryRow:
                                        def __init__(self, sd):
                                            self.hn_id = sd.hn_id
                                            self.raw_payload = sd.raw_payload

                                    story_row = StoryRow(sd_local)
                                    res = await run_summary_for_story_if_enabled(bg_session, story_row, provider, summary_repo, summary_cache, mv_local)

                                    if res is None:
                                        logger.info("summary_skipped", extra={"hn_id": sd_local.hn_id, "model_version": mv_local})
                                    else:
                                        _, created_s, updated_s = res
                                        if created_s:
                                            logger.info("summary_created", extra={"hn_id": sd_local.hn_id, "model_version": mv_local})
                                        elif updated_s:
                                            logger.info("summary_updated", extra={"hn_id": sd_local.hn_id, "model_version": mv_local})
                                        else:
                                            logger.info("summary_skipped", extra={"hn_id": sd_local.hn_id, "model_version": mv_local})
                            except Exception:
                                logger.exception("summary_failed", exc_info=True, extra={"hn_id": getattr(sd, "hn_id", None)})

                        # schedule background execution and don't await
                        asyncio.create_task(_background_summary(sd, mv))
                except Exception:
                    # ensure summarization errors don't block persistence loop
                    logger.exception("Error scheduling summarization for %s", getattr(sd, "hn_id", None))

            except Exception:
                logger.exception("Failed to upsert story %s", getattr(sd, "hn_id", None))

        # replace top stories list
        if top_story_repo is not None:
            top_story_repo.replace_top_stories(session, top_ids)

        # prime the cache after DB upserts
        await feed_cache.prime_feed(session, limit=limit)

    logger.info("Fetch cycle complete: inserted=%d updated=%d", inserted, updated)
    return inserted, updated


# --- Optional summarization hook (guarded by config flag) ---
from app.config import settings
from app.services.ai.base import AIProvider
from app.repositories.summary_repo import SummaryRepository
from app.services.cache.summary_cache import SummaryCache


async def run_summary_for_story_if_enabled(session, story_row, provider: AIProvider, summary_repo: SummaryRepository, summary_cache: SummaryCache, model_version: str, model_name: str | None = None):
    """Optionally generate and persist a summary for a story.

    This function is intentionally not invoked by default. It is exposed as a hook
    that can be used by the worker when ENABLE_SUMMARIZATION is True.
    """
    if not settings.ENABLE_SUMMARIZATION:
        return None

    # provider.summarize_story returns SummaryData
    summary = await provider.summarize_story(story_row.raw_payload or {"id": story_row.hn_id})

    # Upsert into DB
    row, created, updated = summary_repo.upsert_summary(session, story_row.hn_id, summary, model_version, model_name)

    # Populate cache
    payload = {
        "tldr": row.tldr,
        "key_points": row.key_points,
        "consensus": row.consensus,
        "model_version": row.model_version,
        "model_name": row.model_name,
        "created_at": row.created_at.isoformat() if row.created_at else None,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }
    await summary_cache.set(story_row.hn_id, model_version, payload)

    return row, created, updated
