from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.routers import auth, evidence, notifications, officer, reports

app = FastAPI(title="HERVOICE API", version="0.1.0", docs_url="/docs")
app.include_router(auth.router)
app.include_router(reports.router)
app.include_router(evidence.router)
app.include_router(notifications.router)
app.include_router(officer.router)
app.mount("/admin", StaticFiles(directory=Path(__file__).parent / "static" / "admin", html=True), name="admin")


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}
