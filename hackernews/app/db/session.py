"""Database session and engine helpers for MVP v1."""
from typing import Generator, Optional
from contextlib import contextmanager
from sqlalchemy import create_engine
from sqlalchemy.engine.url import make_url
from sqlalchemy.orm import sessionmaker, declarative_base, Session

# Declarative base for models
Base = declarative_base()


def get_engine(database_url: str):
    url = make_url(database_url)
    connect_args = {}
    if url.drivername.startswith("sqlite"):
        # SQLite needs check_same_thread=False for sessions across threads
        connect_args = {"check_same_thread": False}
    return create_engine(database_url, connect_args=connect_args, pool_pre_ping=True)


def init_sessionmaker(engine) -> sessionmaker:
    return sessionmaker(bind=engine, expire_on_commit=False)


@contextmanager
def get_session(SessionLocal: sessionmaker) -> Generator[Session, None, None]:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
