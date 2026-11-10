from typing import Literal
from urllib.parse import urlsplit
from pydantic import AliasChoices, Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Load backend dotenv files; process environment always takes precedence."""

    model_config = SettingsConfigDict(env_file=(".env", ".env.local"), extra="ignore", hide_input_in_errors=True)

    cors_origins: list[str] = ["http://127.0.0.1:8765", "http://localhost:8765"]
    app_env: Literal["development", "staging", "production"] = "development"
    database_connect_timeout: int = Field(5, ge=1, le=30)
    database_statement_timeout_ms: int = Field(15000, ge=1000, le=60000)
    push_enabled: bool = False
    email_delivery: Literal['disabled', 'file', 'smtp'] = 'disabled'
    email_preview_path: str = '.prototype/mail'
    smtp_host: str = ''
    smtp_port: int = 587
    smtp_user: str = ''
    smtp_password: str = ''
    smtp_from: str = ''
    smtp_security: Literal['starttls', 'ssl'] = 'starttls'
    database_url: str
    database_url_unpooled: str | None = None
    jwt_secret: str
    jwt_algorithm: Literal["HS256"] = "HS256"
    access_token_minutes: int = Field(30, ge=1, le=1440)
    object_storage_endpoint: str = Field(validation_alias=AliasChoices('object_storage_endpoint', 'AWS_ENDPOINT_URL_S3'))
    object_storage_access_key: str = Field(validation_alias=AliasChoices('object_storage_access_key', 'AWS_ACCESS_KEY_ID'))
    object_storage_secret_key: str = Field(validation_alias=AliasChoices('object_storage_secret_key', 'AWS_SECRET_ACCESS_KEY'))
    object_storage_region: str | None = Field(default=None,
        validation_alias=AliasChoices('object_storage_region', 'AWS_REGION', 'AWS_DEFAULT_REGION'))
    object_storage_bucket: str = "hervoice-evidence"
    evidence_storage: Literal['s3', 'local'] = 's3'
    local_evidence_path: str = '.prototype/evidence'
    max_evidence_bytes: int = Field(10 * 1024 * 1024, ge=1, le=10 * 1024 * 1024)

    @field_validator('database_url', 'database_url_unpooled', mode='before')
    @classmethod
    def psycopg_database_url(cls, value):
        # Neon emits standard Postgres URLs; select our installed psycopg 3 driver.
        if isinstance(value, str):
            for prefix in ('postgresql://', 'postgres://'):
                if value.startswith(prefix):
                    return 'postgresql+psycopg://' + value[len(prefix):]
        return value

    @property
    def migration_database_url(self) -> str:
        """Use a direct connection for Alembic, falling back for non-Neon setups."""
        return self.database_url_unpooled or self.database_url

    @model_validator(mode='after')
    def deployment_settings(self):
        if self.app_env == 'development':
            return self
        def placeholder(value):
            return not value or any(word in value.lower() for word in
                ('replace', 'change-me', 'example', 'fictional'))
        if len(self.jwt_secret) < 32 or placeholder(self.jwt_secret):
            raise ValueError('A generated JWT secret of at least 32 characters is required')
        database = urlsplit(self.database_url)
        if not database.scheme.startswith('postgresql') or not database.hostname or placeholder(database.password):
            raise ValueError('A private PostgreSQL connection with real credentials is required')
        if self.evidence_storage != 's3':
            raise ValueError('Hosted environments require private S3-compatible evidence storage')
        storage = urlsplit(self.object_storage_endpoint)
        if storage.scheme != 'https' or not storage.hostname or storage.username or storage.query or storage.fragment or any(placeholder(v) for v in
                (self.object_storage_access_key, self.object_storage_secret_key)):
            raise ValueError('HTTPS evidence storage and non-placeholder credentials are required')
        staging_without_mail = self.app_env == 'staging' and self.email_delivery == 'disabled'
        if not staging_without_mail and (self.email_delivery != 'smtp' or not self.smtp_host or not self.smtp_from):
            raise ValueError('Hosted environments require configured SMTP delivery')
        def valid_origin(origin):
            parsed = urlsplit(origin)
            return (parsed.scheme == 'https' and bool(parsed.hostname) and not parsed.username
                    and not parsed.path and not parsed.query and not parsed.fragment)
        if not self.cors_origins or not all(valid_origin(origin) for origin in self.cors_origins):
            raise ValueError('Hosted browser origins must use HTTPS')
        return self


settings = Settings()
