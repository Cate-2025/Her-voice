from collections.abc import Generator

from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings


engine = create_engine(settings.database_url, pool_pre_ping=True, pool_timeout=5,
    connect_args={"connect_timeout": settings.database_connect_timeout})


@event.listens_for(engine, 'begin')
def transaction_timeout(connection):
    # Transaction-local settings survive neither commit nor PgBouncer reassignment.
    # Startup/session options cannot reliably enforce limits through transaction pooling.
    connection.exec_driver_sql("SELECT set_config('statement_timeout', %s, true)",
        (str(settings.database_statement_timeout_ms),))


SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
