from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration. Values come from backend/.env, never source code."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    database_url: str
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    object_storage_endpoint: str
    object_storage_access_key: str
    object_storage_secret_key: str
    object_storage_bucket: str = "hervoice-evidence"
    max_evidence_bytes: int = 10 * 1024 * 1024


settings = Settings()
