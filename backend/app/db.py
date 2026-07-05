"""DB 엔진/세션 — 로컬은 SQLite, 배포는 Postgres(DATABASE_URL).

Railway 는 Postgres 추가 시 DATABASE_URL 을 자동 주입한다(형식 postgres://... →
SQLAlchemy 용 postgresql:// 로 정규화). 미설정 시 로컬 파일 SQLite 로 폴백.
"""

import os

from sqlmodel import Session, SQLModel, create_engine


def _database_url() -> str:
    url = os.getenv("DATABASE_URL") or os.getenv("PETFIT_DATABASE_URL")
    if not url:
        # 로컬 개발/테스트: 파일 SQLite (서버 재시작에도 유지)
        return "sqlite:///./pawdy.db"
    # Railway/Heroku 는 postgres:// 로 주는데 SQLAlchemy 는 postgresql:// 필요
    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql://", 1)
    return url


DATABASE_URL = _database_url()
_connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, echo=False, pool_pre_ping=True, connect_args=_connect_args)


def init_db() -> None:
    """앱 시작 시 테이블 생성(없으면). tables 모듈을 import 해야 메타데이터가 등록됨."""
    from . import tables  # noqa: F401

    SQLModel.metadata.create_all(engine)


def get_session() -> Session:
    return Session(engine)
