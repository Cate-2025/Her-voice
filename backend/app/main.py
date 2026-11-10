from pathlib import Path
from contextlib import asynccontextmanager
from threading import Event, Thread
import asyncio

from fastapi import FastAPI, Response
from sqlalchemy import text
from alembic.config import Config
from alembic.script import ScriptDirectory
from app.database import engine
from app.services.storage import storage_client
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from fastapi.staticfiles import StaticFiles

from app.routers import auth, evidence, notifications, officer, reports

@asynccontextmanager
async def lifespan(app):
    if not settings.push_enabled:
        yield
        return
    from app.services.push import FirebaseSender, run_worker
    sender = FirebaseSender()
    stop = Event()
    worker = Thread(target=run_worker, args=(stop, sender), daemon=True)
    worker.start()
    try:
        yield
    finally:
        stop.set()
        await asyncio.to_thread(worker.join)
        sender.close()


app = FastAPI(title="HERVOICE API", version="0.2.0", docs_url="/docs" if settings.app_env == "development" else None,
    redoc_url=None, openapi_url="/openapi.json" if settings.app_env == "development" else None, lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
                   allow_methods=["GET", "POST", "PUT", "PATCH"], allow_headers=["Authorization", "Content-Type", "X-Evidence-Name", "X-Evidence-SHA256"])
app.include_router(auth.router)
app.include_router(reports.router)
app.include_router(evidence.router)
app.include_router(notifications.router)
app.include_router(officer.router)
app.mount("/admin", StaticFiles(directory=Path(__file__).parent / "static" / "admin", html=True), name="admin")


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get('/ready', include_in_schema=False)
def readiness(response: Response):
    """Required data dependencies only; never expose credentials or exception text."""
    response.headers['Cache-Control'] = 'no-store'
    try:
        with engine.connect() as connection:
            connection.execute(text('SELECT 1'))
            expected = set(ScriptDirectory.from_config(Config(str(Path(__file__).resolve().parents[1] / 'alembic.ini'))).get_heads())
            installed = set(connection.execute(text('SELECT version_num FROM alembic_version')).scalars())
            if installed != expected:
                raise RuntimeError('Database schema is not current')
        if settings.evidence_storage == 's3':
            storage_client().head_bucket(Bucket=settings.object_storage_bucket)
        else:
            # Local mode is development-only; check a private scratch file,
            # without reading or changing any report evidence.
            import tempfile
            root = Path(settings.local_evidence_path)
            root.mkdir(parents=True, exist_ok=True, mode=0o700)
            with tempfile.TemporaryFile(dir=root) as probe:
                probe.write(b'ready')
                probe.flush()
                probe.seek(0)
                if probe.read() != b'ready':
                    raise RuntimeError('Storage probe failed')
    except Exception:
        response.status_code = 503
        return {'status': 'unavailable'}
    return {'status': 'ready'}
