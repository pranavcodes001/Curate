from fastapi import FastAPI
import logging
from typing import Optional

from app.config import settings
from app.db.session import get_engine, init_sessionmaker
from app.db.base import Base
from app.services.cache.redis import RedisCache
from app.repositories.story_repo import StoryRepository
from app.repositories.top_story_repo import TopStoryRepository
from app.api.v1 import routers as api_v1_routers

logger = logging.getLogger(__name__)


def create_app(redis_cache: Optional[RedisCache] = None, engine=None) -> FastAPI:
    app = FastAPI(title="HN Clarity Backend - MVP v1")

    # DB engine and SessionLocal
    if engine is None:
        engine = get_engine(settings.DATABASE_URL)
    SessionLocal = init_sessionmaker(engine)

    # Optionally auto-create schema in dev (prefer Alembic migrations)
    if settings.DB_AUTO_CREATE:
        Base.metadata.create_all(engine)

    # Redis cache
    if redis_cache is None:
        redis_url = settings.REDIS_URL if settings.REDIS_ENABLED else None
        redis_cache = RedisCache(url=redis_url)

    app.state.redis_cache = redis_cache
    app.state.SessionLocal = SessionLocal
    app.state.story_repo = StoryRepository()
    app.state.top_story_repo = TopStoryRepository()

    # include routers
    app.include_router(api_v1_routers.router, prefix="/v1")

    @app.on_event("startup")
    async def _startup():
        logger.info("Starting app: initializing redis cache")
        await app.state.redis_cache.init()

    @app.on_event("shutdown")
    async def _shutdown():
        logger.info("Shutting down app: closing redis cache")
        await app.state.redis_cache.close()

    return app


app = create_app()
