FROM python:3.12-slim
ENV APP_ENV=production PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home hervoice
COPY --chown=hervoice:hervoice app ./app
COPY --chown=hervoice:hervoice migrations ./migrations
COPY --chown=hervoice:hervoice alembic.ini ./alembic.ini
COPY --chown=hervoice:hervoice scripts/bootstrap_admin.py ./scripts/bootstrap_admin.py
COPY --chown=hervoice:hervoice scripts/run_render.py ./scripts/run_render.py
USER 10001:10001
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "172.29.88.2", "--no-access-log", "--limit-concurrency", "32"]
