"""DB 엔진/세션 — 로컬은 SQLite, 배포는 Postgres(DATABASE_URL).

Railway 는 Postgres 추가 시 DATABASE_URL 을 자동 주입한다(형식 postgres://... →
SQLAlchemy 용 postgresql:// 로 정규화). 미설정 시 로컬 파일 SQLite 로 폴백.
"""

import os
import json

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
    from .data import PRODUCTS
    from sqlmodel import select

    # 프로덕션(Railway) 오설정 방어: DATABASE_URL 없이 SQLite 폴백으로 뜨면 재배포/재시작마다
    # 유저·주문 데이터가 통째로 날아간다 → 조용히 뜨는 대신 기동 실패로 크게 알린다.
    if DATABASE_URL.startswith("sqlite") and (
        os.getenv("RAILWAY_ENVIRONMENT_NAME") or os.getenv("RAILWAY_PROJECT_ID")
    ):
        raise RuntimeError(
            "Railway 환경에서 SQLite 폴백이 감지됨 — Postgres 플러그인 연결 및 "
            "DATABASE_URL 주입 여부를 확인하세요."
        )

    SQLModel.metadata.create_all(engine)

    # 기존 products 테이블에 신규 컬럼(shop_id, stock)이 없을 경우를 대비한 동적 마이그레이션
    from sqlalchemy import text
    for col_name, col_type in [
        ("shop_id", "INTEGER"),
        ("stock", "INTEGER DEFAULT 99")
    ]:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE products ADD COLUMN {col_name} {col_type}"))
        except Exception:
            # 컬럼이 이미 존재하거나 DB 상태에 따른 오류 발생 시 개별적으로 안전하게 스킵
            pass

    # 기존 orders 테이블에 신규 컬럼(status)이 없을 경우를 대비한 동적 마이그레이션
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE orders ADD COLUMN status VARCHAR(50) DEFAULT '결제완료'"))
    except Exception:
        pass

    # orders 테이블에 carrier 및 tracking_no 컬럼 동적 추가
    for col in [("carrier", "VARCHAR(100)"), ("tracking_no", "VARCHAR(100)")]:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE orders ADD COLUMN {col[0]} {col[1]}"))
        except Exception:
            pass

    # orders 테이블에 payment_key 컬럼 동적 추가
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE orders ADD COLUMN payment_key VARCHAR(255)"))
    except Exception:
        pass


    # reviews 테이블에 image 컬럼 동적 추가
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE reviews ADD COLUMN image VARCHAR(255)"))
    except Exception:
        pass

    # pets 테이블에 image 컬럼 동적 추가
    try:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE pets ADD COLUMN image VARCHAR(255)"))
    except Exception:
        pass

    # users 테이블에 email, password_hash, google_id 컬럼 동적 추가
    for col, col_type in [
        ("email", "VARCHAR(150)"),
        ("password_hash", "VARCHAR(255)"),
        ("google_id", "VARCHAR(150)")
    ]:
        try:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE users ADD COLUMN {col} {col_type}"))
        except Exception:
            pass








    with Session(engine) as s:
        # products 테이블에 데이터가 없는 경우에만 초기 데이터 시딩
        existing = s.exec(select(tables.ProductRow)).first()
        if not existing:
            for p in PRODUCTS:
                sizes_json = json.dumps(p.sizes) if p.sizes else None
                # 테스트 목적으로 id=2(빅 블랙 퍼퍼 재킷)인 경우 재고를 0(품절)으로 설정하고 나머지는 50개 설정
                stock_val = 0 if p.id == 2 else 50
                row = tables.ProductRow(
                    id=p.id,
                    brand=p.brand,
                    name=p.name,
                    price=p.price,
                    fit=p.fit,
                    category=p.category,
                    species=p.species,
                    fittable=p.fittable,
                    image=p.image,
                    ref_image=p.ref_image,
                    url=p.url,
                    sizes_json=sizes_json,
                    stock=stock_val
                )
                s.add(row)
            s.commit()

    # PostgreSQL의 경우, 시딩 시 수동으로 ID를 주입하였으므로 기본키 시퀀스 값을 테이블 최댓값으로 조정해야 함
    if engine.dialect.name == "postgresql":
        try:
            with engine.begin() as conn:
                conn.execute(text("SELECT setval(pg_get_serial_sequence('products', 'id'), COALESCE((SELECT MAX(id) FROM products), 1))"))
        except Exception:
            pass




def get_session() -> Session:
    return Session(engine)

