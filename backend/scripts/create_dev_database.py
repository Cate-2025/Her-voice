"""Create tables only for local prototype development.

Use Alembic migrations before staging or production deployment.
"""

from app import models  # noqa: F401 - imports every mapped model
from app.database import Base, engine

Base.metadata.create_all(bind=engine)
print("Development database tables created.")
