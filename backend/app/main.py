from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from fastapi.staticfiles import StaticFiles

from app.routers import auth, evidence, notifications, officer, reports

app = FastAPI(title="HERVOICE API", version="0.2.0", docs_url="/docs")
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
                   allow_methods=["GET", "POST"], allow_headers=["Authorization", "Content-Type"])
app.include_router(auth.router)
app.include_router(reports.router)
app.include_router(evidence.router)
app.include_router(notifications.router)
app.include_router(officer.router)
app.mount("/admin", StaticFiles(directory=Path(__file__).parent / "static" / "admin", html=True), name="admin")


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
