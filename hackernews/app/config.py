from pydantic_settings import BaseSettings
from pydantic import Field, AnyUrl

from typing import Optional


class Settings(BaseSettings):
    # External services
    HN_API_URL: AnyUrl = Field("https://hacker-news.firebaseio.com/v0", env="HN_API_URL")

    # Redis
    REDIS_ENABLED: bool = True
    REDIS_URL: str | None = "redis://localhost:6379"


    # Database (SQLite for MVP)
    DATABASE_URL: str = Field("sqlite:///./dev.db", env="DATABASE_URL")

    # Search (HN Algolia)
    SEARCH_API_URL: AnyUrl = Field("https://hn.algolia.com/api/v1/search", env="SEARCH_API_URL")
    SEARCH_TTL_SECONDS: int = Field(300, env="SEARCH_TTL_SECONDS")
    SEARCH_LIMIT: int = Field(20, env="SEARCH_LIMIT")
    SEARCH_MAX_KEYWORDS: int = Field(5, env="SEARCH_MAX_KEYWORDS")
    SEARCH_DB_TTL_DAYS: int = Field(7, env="SEARCH_DB_TTL_DAYS")

    # Interests feed
    INTEREST_REFRESH_SECONDS: int = Field(900, env="INTEREST_REFRESH_SECONDS")
    INTEREST_BACKLOG_LIMIT: int = Field(50, env="INTEREST_BACKLOG_LIMIT")
    INTEREST_STORY_LIMIT: int = Field(10, env="INTEREST_STORY_LIMIT")

    # Top stories (global)
    TOP_STORIES_LIMIT: int = Field(50, env="TOP_STORIES_LIMIT")
    TOP_STORIES_REFRESH_SECONDS: int = Field(86400, env="TOP_STORIES_REFRESH_SECONDS")

    # Fetching / operational
    FETCH_INTERVAL_SECONDS: int = Field(60, env="FETCH_INTERVAL_SECONDS")
    FEED_LIMIT: int = Field(50, env="FEED_LIMIT")
    FEED_TTL_SECONDS: int = Field(300, env="FEED_TTL_SECONDS")
    CLEANUP_INTERVAL_SECONDS: int = Field(86400, env="CLEANUP_INTERVAL_SECONDS")
    CLEANUP_RETENTION_DAYS: int = Field(7, env="CLEANUP_RETENTION_DAYS")

    # Misc
    LOG_LEVEL: str = Field("INFO", env="LOG_LEVEL")

    # For future: token/budget controls, model ids etc.
    AI_PROVIDER: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = Field(None, env="OPENAI_API_KEY")
    OPENAI_MODEL: Optional[str] = Field(None, env="OPENAI_MODEL")

    # Summarization feature flags and cache TTL
    ENABLE_SUMMARIZATION: bool = Field(False, env="ENABLE_SUMMARIZATION")
    SUMMARY_TTL_SECONDS: int = Field(3600, env="SUMMARY_TTL_SECONDS")
    SUMMARIZATION_MODEL_VERSION: str = Field("mock-v1", env="SUMMARIZATION_MODEL_VERSION")
    SUMMARY_RATE_LIMIT_PER_HOUR: int = Field(30, env="SUMMARY_RATE_LIMIT_PER_HOUR")
    SUMMARY_QUEUE_MAX_PER_TICK: int = Field(20, env="SUMMARY_QUEUE_MAX_PER_TICK")

    # Comments ingestion / previews
    COMMENTS_PREVIEW_LIMIT: int = Field(5, env="COMMENTS_PREVIEW_LIMIT")
    COMMENTS_FETCH_LIMIT: int = Field(100, env="COMMENTS_FETCH_LIMIT")

    # Saved threads queue
    SAVED_THREAD_QUEUE_MAX_PER_TICK: int = Field(10, env="SAVED_THREAD_QUEUE_MAX_PER_TICK")


    # Auth (JWT)
    JWT_SECRET: str = Field("dev-secret", env="JWT_SECRET")
    JWT_ALGORITHM: str = Field("HS256", env="JWT_ALGORITHM")
    JWT_ACCESS_TTL_MINUTES: int = Field(60, env="JWT_ACCESS_TTL_MINUTES")
    JWT_REFRESH_TTL_DAYS: int = Field(30, env="JWT_REFRESH_TTL_DAYS")

    # Admin credentials (for protected endpoints)
    ADMIN_USERNAME: Optional[str] = Field(None, env="ADMIN_USERNAME")
    ADMIN_PASSWORD: Optional[str] = Field(None, env="ADMIN_PASSWORD")

    # DB auto-create (dev convenience; prefer Alembic migrations)
    DB_AUTO_CREATE: bool = Field(True, env="DB_AUTO_CREATE")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
