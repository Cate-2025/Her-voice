"""Bounded list requests with stable ordering supplied by each endpoint."""
from fastapi import Query


class Page:
    def __init__(self, limit: int = Query(100, ge=1, le=100),
                 offset: int = Query(0, ge=0)):
        self.limit = limit
        self.offset = offset

    def apply(self, query):
        return query.limit(self.limit).offset(self.offset)
